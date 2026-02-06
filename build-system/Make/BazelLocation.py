import os
import stat
import sys
from urllib.parse import urlparse, urlunparse
import tempfile
import hashlib
import shutil

from BuildEnvironment import is_apple_silicon, resolve_executable, call_executable, run_executable_with_status, BuildEnvironmentVersions

def transform_cache_host_into_http(grpc_url):
    parsed_url = urlparse(grpc_url)
    
    new_scheme = "http"
    new_port = 8080
    
    transformed_url = urlunparse((
        new_scheme,
        f"{parsed_url.hostname}:{new_port}",
        parsed_url.path,
        parsed_url.params,
        parsed_url.query,
        parsed_url.fragment
    ))
    
    return transformed_url

def calculate_sha256(file_path):
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as file:
        # Read the file in chunks to avoid using too much memory
        for byte_block in iter(lambda: file.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def resolve_cache_host(cache_host):
    if cache_host is None:
        return None
    if cache_host.startswith("file://"):
        return None
    if "@auto" in cache_host:
        host_parts = cache_host.split("@auto")
        host_left_part = host_parts[0]
        host_right_part = host_parts[1]
        return f"{host_left_part}localhost{host_right_part}"
    return cache_host

def resolve_cache_path(cache_host_or_path, cache_dir):
    if cache_dir is not None:
        return cache_dir
    if cache_host_or_path is not None:
        if cache_host_or_path.startswith("file://"):
            return cache_host_or_path.replace("file://", "")
    return None

def cache_cas_name(digest):
    return (digest[:2], digest)

def locate_bazel(base_path, cache_host_or_path, cache_dir):
     # Always use system Bazel (Bazelisk)
    bazel_path = shutil.which("bazel")
    if not bazel_path:
        raise Exception("Bazel not found. Install Bazelisk: brew install bazelisk")
    return bazel_path
