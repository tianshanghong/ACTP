#!/usr/bin/env python3
"""
Ansible bcrypt Compatibility Patch

This script patches the bcrypt module to work with Ansible's passlib integration.
It fixes the 'module has no attribute __about__' error by adding the missing attribute.

Usage:
    python3 bcrypt_patch.py [--path ANSIBLE_PYTHON_PATH] [--check] [--force]

Options:
    --path     Specify the Ansible Python site-packages path (auto-detected by default)
    --check    Check if the patch is needed without applying it
    --force    Apply the patch even if it seems already applied
    --help     Show this help message
"""

import os
import sys
import subprocess
import argparse
import importlib.util
from pathlib import Path


def find_ansible_python_paths():
    """Find potential Ansible Python environments."""
    potential_paths = []
    
    # Common Homebrew installation paths
    homebrew_paths = [
        "/opt/homebrew/Cellar/ansible",
        "/usr/local/Cellar/ansible"
    ]
    
    # Common system paths
    system_paths = [
        "/usr/lib/python*/site-packages",
        "/usr/local/lib/python*/site-packages",
        "/opt/local/lib/python*/site-packages"
    ]
    
    # Check if ansible is in PATH and get its location
    try:
        ansible_path = subprocess.check_output(["which", "ansible"], 
                                              stderr=subprocess.DEVNULL,
                                              universal_newlines=True).strip()
        if ansible_path:
            # If ansible is a symlink, find the real path
            real_path = os.path.realpath(ansible_path)
            ansible_dir = os.path.dirname(os.path.dirname(real_path))
            
            # Check for libexec style paths (homebrew)
            libexec_path = os.path.join(ansible_dir, "libexec", "lib")
            if os.path.exists(libexec_path):
                for py_dir in os.listdir(libexec_path):
                    if py_dir.startswith("python"):
                        site_packages = os.path.join(libexec_path, py_dir, "site-packages")
                        if os.path.exists(site_packages):
                            potential_paths.append(site_packages)
    except subprocess.CalledProcessError:
        pass

    # Check Homebrew paths
    for base_path in homebrew_paths:
        if os.path.exists(base_path):
            try:
                # Get the latest version directory
                ansible_versions = [d for d in os.listdir(base_path) if os.path.isdir(os.path.join(base_path, d))]
                if ansible_versions:
                    latest_version = sorted(ansible_versions, key=lambda v: [int(x) if x.isdigit() else x for x in v.split('.')])[-1]
                    libexec_path = os.path.join(base_path, latest_version, "libexec", "lib")
                    
                    if os.path.exists(libexec_path):
                        for py_dir in os.listdir(libexec_path):
                            if py_dir.startswith("python"):
                                site_packages = os.path.join(libexec_path, py_dir, "site-packages")
                                if os.path.exists(site_packages):
                                    potential_paths.append(site_packages)
            except (FileNotFoundError, IndexError, OSError):
                continue
    
    # Use glob for system paths
    for pattern in system_paths:
        import glob
        for path in glob.glob(pattern):
            if os.path.exists(path):
                potential_paths.append(path)
    
    return potential_paths


def check_bcrypt_missing_about(site_packages_path):
    """Check if bcrypt is installed and missing the __about__ attribute."""
    bcrypt_path = os.path.join(site_packages_path, "bcrypt")
    
    if not os.path.exists(bcrypt_path):
        return False, "bcrypt is not installed at this location"
    
    # Try to load bcrypt from this path
    try:
        sys.path.insert(0, site_packages_path)
        bcrypt_spec = importlib.util.find_spec("bcrypt")
        if not bcrypt_spec:
            return False, "bcrypt module could not be imported"
        
        bcrypt = importlib.util.module_from_spec(bcrypt_spec)
        bcrypt_spec.loader.exec_module(bcrypt)
        
        # Check if __about__ attribute is missing
        if hasattr(bcrypt, '__about__'):
            return False, "bcrypt already has __about__ attribute"
        
        return True, "bcrypt is missing __about__ attribute"
    except Exception as e:
        return False, f"Error checking bcrypt: {str(e)}"
    finally:
        if site_packages_path in sys.path:
            sys.path.remove(site_packages_path)


def create_patch(site_packages_path, force=False):
    """Create the bcrypt patch in the site-packages directory."""
    needs_patch, message = check_bcrypt_missing_about(site_packages_path)
    
    if not needs_patch and not force:
        print(f"❌ {message} - Patch not needed")
        return False
    
    patch_content = '''
# Add __about__ attribute to bcrypt module
import bcrypt

if not hasattr(bcrypt, '__about__'):
    class About:
        __version__ = bcrypt.__version__
    bcrypt.__about__ = About()
    print("bcrypt.__about__ attribute added successfully")
'''
    
    # Create the patch file in the site-packages directory
    patch_file_path = os.path.join(site_packages_path, 'bcrypt_patch.py')
    patch_init_path = os.path.join(site_packages_path, 'bcrypt_patch.pth')
    
    try:
        with open(patch_file_path, 'w') as f:
            f.write(patch_content)
        print(f"✅ Created patch file: {patch_file_path}")
        
        with open(patch_init_path, 'w') as f:
            f.write('import bcrypt_patch\n')
        print(f"✅ Created .pth file: {patch_init_path}")
        
        print("\n🎉 bcrypt patch installed successfully!")
        print("   The patch will be applied when Ansible imports bcrypt.")
        return True
    except Exception as e:
        print(f"❌ Error creating patch: {str(e)}")
        return False


def parse_args():
    parser = argparse.ArgumentParser(description='Ansible bcrypt Compatibility Patch')
    parser.add_argument('--path', help='Specify Ansible Python site-packages path')
    parser.add_argument('--check', action='store_true', help='Check if patch is needed without applying')
    parser.add_argument('--force', action='store_true', help='Apply patch even if it seems already applied')
    return parser.parse_args()


def main():
    args = parse_args()
    
    # Banner
    print("=" * 70)
    print("🔧 Ansible bcrypt Compatibility Patch 🔧")
    print("=" * 70)
    
    # If path is specified, use it
    if args.path:
        paths_to_check = [args.path]
    else:
        print("🔍 Searching for Ansible Python environments...")
        paths_to_check = find_ansible_python_paths()
        
        if not paths_to_check:
            print("❌ No Ansible Python environments found automatically.")
            print("   Please specify the path with --path")
            return 1
    
    # Check all potential paths
    found_valid_path = False
    
    for path in paths_to_check:
        print(f"\n📦 Checking: {path}")
        
        if not os.path.exists(path):
            print(f"❌ Path does not exist: {path}")
            continue
            
        needs_patch, message = check_bcrypt_missing_about(path)
        
        if needs_patch:
            print(f"✓ Found bcrypt installation: {message}")
            found_valid_path = True
            
            if args.check:
                print("ℹ️ Check mode: Patch is needed but not applied")
            else:
                create_patch(path, force=args.force)
            
            # No need to check other paths if we found one that needs patching
            break
        else:
            print(f"ℹ️ {message}")
    
    if not found_valid_path:
        print("\n❌ No valid bcrypt installations found that need patching.")
        print("   If you believe this is incorrect, try with --force")
        return 1
    
    print("\n🔧 Patch process completed")
    return 0


if __name__ == "__main__":
    sys.exit(main()) 