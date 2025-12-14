#!/usr/bin/env bash

# ReactJsonUI Installer Script
# This script downloads and installs rjui_tools (unified tool for React component generation)

set -e

# Default values
GITHUB_REPO="Tai-Kimura/ReactJsonUI"
DEFAULT_BRANCH="main"
INSTALL_DIR=".."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -v, --version <version>    Specify version/branch/tag/commit to download (default: main)"
    echo "  -d, --directory <dir>      Installation directory (default: parent directory)"
    echo "  -s, --skip-bundle          Skip bundle install for Ruby dependencies"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                         # Install latest from main branch to parent directory"
    echo "  $0 -v v1.0.0               # Install specific version (tag)"
    echo "  $0 -v 1.2.0                # Install from branch (e.g., unreleased version)"
    echo "  $0 -v feature-branch       # Install from specific branch"
    echo "  $0 -v a1b2c3d              # Install from specific commit hash"
    echo "  $0 -d ./my-project         # Install in specific directory"
    echo "  $0 -s                      # Skip bundle install"
    exit 0
}

# Parse command line arguments
VERSION=""
SKIP_BUNDLE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -d|--directory)
            INSTALL_DIR="$2"
            shift 2
            ;;
        -s|--skip-bundle)
            SKIP_BUNDLE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Use default branch if no version specified
if [ -z "$VERSION" ]; then
    VERSION="$DEFAULT_BRANCH"
fi

# Validate installation directory
if [ ! -d "$INSTALL_DIR" ]; then
    print_error "Installation directory does not exist: $INSTALL_DIR"
    exit 1
fi

# Change to installation directory
cd "$INSTALL_DIR"

print_info "Installing ReactJsonUI tools..."
print_info "Version: $VERSION"
print_info "Directory: $(pwd)"

# Check if rjui_tools already exists
if [ -d "rjui_tools" ]; then
    print_warning "rjui_tools directory already exists."
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled."
        exit 0
    else
        rm -rf rjui_tools
    fi
fi

# Create temporary directory for download
TEMP_DIR=$(mktemp -d)
print_info "Created temporary directory: $TEMP_DIR"

# Cleanup function
cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        print_info "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Download the archive
print_info "Downloading ReactJsonUI $VERSION..."

# Determine download URL based on VERSION format:
# - v1.0.0 or 1.0.0 (with dots) → tag
# - a1b2c3d (7-40 hex chars, no dots) → commit hash
# - anything else → branch
if [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+ ]]; then
    # Tag with 'v' prefix (e.g., v1.0.0)
    DOWNLOAD_URL="https://github.com/$GITHUB_REPO/archive/refs/tags/$VERSION.tar.gz"
    print_info "Detected: tag"
elif [[ "$VERSION" =~ ^[0-9]+\.[0-9]+ ]] && [[ ! "$VERSION" =~ ^[0-9a-fA-F]+$ ]]; then
    # Version number without 'v' but with dots (e.g., 1.2.0) - treat as branch
    DOWNLOAD_URL="https://github.com/$GITHUB_REPO/archive/$VERSION.tar.gz"
    print_info "Detected: branch (version number)"
elif [[ "$VERSION" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
    # Commit hash (7-40 hex characters)
    DOWNLOAD_URL="https://github.com/$GITHUB_REPO/archive/$VERSION.tar.gz"
    print_info "Detected: commit hash"
else
    # Branch name
    DOWNLOAD_URL="https://github.com/$GITHUB_REPO/archive/$VERSION.tar.gz"
    print_info "Detected: branch"
fi

if ! curl -L -f -o "$TEMP_DIR/reactjsonui.tar.gz" "$DOWNLOAD_URL"; then
    print_error "Failed to download from $DOWNLOAD_URL"
    print_error "Please check if the version/branch '$VERSION' exists."
    exit 1
fi

# Extract the archive
print_info "Extracting archive..."
tar -xzf "$TEMP_DIR/reactjsonui.tar.gz" -C "$TEMP_DIR"

# Find the extracted directory (it will have a dynamic name based on version)
EXTRACT_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "ReactJsonUI-*" | head -1)

if [ -z "$EXTRACT_DIR" ]; then
    print_error "Failed to find extracted directory"
    exit 1
fi

# Copy rjui_tools (excluding unnecessary files)
if [ -d "$EXTRACT_DIR/rjui_tools" ]; then
    print_info "Installing rjui_tools..."
    mkdir -p rjui_tools

    # Copy only necessary files/directories, excluding:
    # - spec/ (test files)
    # - coverage/ (coverage reports)
    # - .rspec (RSpec config)
    # - .DS_Store (macOS metadata)
    # - .rjui_cache/ (cache)
    # - *.config.json (example config)
    if command -v rsync &> /dev/null; then
        rsync -a --exclude='spec' --exclude='coverage' --exclude='.rspec' \
              --exclude='.DS_Store' --exclude='.rjui_cache' --exclude='*.config.json' \
              "$EXTRACT_DIR/rjui_tools/" rjui_tools/
    else
        # Fallback: copy all then remove unwanted
        cp -r "$EXTRACT_DIR/rjui_tools/"* rjui_tools/
        rm -rf rjui_tools/spec rjui_tools/coverage rjui_tools/.rspec \
               rjui_tools/.DS_Store rjui_tools/.rjui_cache rjui_tools/*.config.json 2>/dev/null || true
    fi

    # Create VERSION file with the downloaded version
    echo "$VERSION" > rjui_tools/VERSION
    print_info "Set rjui_tools version to: $VERSION"

    # Make rjui executable
    if [ -f "rjui_tools/bin/rjui" ]; then
        chmod +x rjui_tools/bin/rjui
        print_info "Made rjui_tools/bin/rjui executable"
    fi

    # Make all .sh and .rb files executable
    find rjui_tools -name "*.sh" -type f -exec chmod +x {} \;
    find rjui_tools -name "*.rb" -type f -exec chmod +x {} \;

    print_info "rjui_tools installed successfully"
else
    print_error "rjui_tools not found in the downloaded version"
    exit 1
fi

# Install Ruby dependencies
if [ -f "rjui_tools/Gemfile" ] && [ "$SKIP_BUNDLE" != true ]; then
    GEMFILE_DIR="rjui_tools"
    print_info "Installing Ruby dependencies..."

    # Check and setup Ruby version
    REQUIRED_RUBY_VERSION="3.2.2"
    MINIMUM_RUBY_VERSION="2.7.0"

    # Function to compare version numbers
    version_compare() {
        printf '%s\n%s' "$1" "$2" | sort -V | head -n1
    }

    # Check if rbenv is installed
    if command -v rbenv &> /dev/null; then
        print_info "Found rbenv"
        CURRENT_RUBY_VERSION=$(ruby -v | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

        if [ "$(version_compare "$CURRENT_RUBY_VERSION" "$MINIMUM_RUBY_VERSION")" != "$MINIMUM_RUBY_VERSION" ]; then
            print_info "Current Ruby version ($CURRENT_RUBY_VERSION) is too old"
            print_info "Installing Ruby $REQUIRED_RUBY_VERSION with rbenv..."

            # Install required Ruby version
            if rbenv install -s "$REQUIRED_RUBY_VERSION"; then
                rbenv local "$REQUIRED_RUBY_VERSION"
                print_info "Ruby $REQUIRED_RUBY_VERSION installed and set as local version"
            else
                print_warning "Failed to install Ruby $REQUIRED_RUBY_VERSION"
                print_warning "Please install it manually: rbenv install $REQUIRED_RUBY_VERSION"
            fi
        else
            print_info "Ruby version $CURRENT_RUBY_VERSION is compatible"
        fi
    # Check if rvm is installed
    elif command -v rvm &> /dev/null || [ -s "$HOME/.rvm/scripts/rvm" ]; then
        print_info "Found rvm"
        # Source rvm if needed
        [ -s "$HOME/.rvm/scripts/rvm" ] && source "$HOME/.rvm/scripts/rvm"

        CURRENT_RUBY_VERSION=$(ruby -v | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)

        if [ "$(version_compare "$CURRENT_RUBY_VERSION" "$MINIMUM_RUBY_VERSION")" != "$MINIMUM_RUBY_VERSION" ]; then
            print_info "Current Ruby version ($CURRENT_RUBY_VERSION) is too old"
            print_info "Installing Ruby $REQUIRED_RUBY_VERSION with rvm..."

            # Install required Ruby version
            if rvm install "$REQUIRED_RUBY_VERSION"; then
                rvm use "$REQUIRED_RUBY_VERSION"
                print_info "Ruby $REQUIRED_RUBY_VERSION installed and activated"
            else
                print_warning "Failed to install Ruby $REQUIRED_RUBY_VERSION"
                print_warning "Please install it manually: rvm install $REQUIRED_RUBY_VERSION"
            fi
        else
            print_info "Ruby version $CURRENT_RUBY_VERSION is compatible"
        fi
    else
        # No Ruby version manager found
        if command -v ruby &> /dev/null; then
            RUBY_VERSION=$(ruby -v | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            print_info "Ruby version: $RUBY_VERSION"

            # Check if Ruby version is at least 2.7.0
            if [ "$(version_compare "$RUBY_VERSION" "$MINIMUM_RUBY_VERSION")" = "$MINIMUM_RUBY_VERSION" ]; then
                print_info "Ruby version is compatible"
            else
                print_warning "Ruby version is older than $MINIMUM_RUBY_VERSION"
                print_warning "Please install rbenv or rvm to manage Ruby versions:"
                print_warning "  rbenv: https://github.com/rbenv/rbenv"
                print_warning "  rvm: https://rvm.io/"
            fi
        else
            print_error "Ruby not found. Please install Ruby $MINIMUM_RUBY_VERSION or later"
            exit 1
        fi
    fi

    cd "$GEMFILE_DIR"

    # Install correct bundler version
    print_info "Checking bundler version..."
    BUNDLER_VERSION=$(grep -A1 "BUNDLED WITH" Gemfile.lock 2>/dev/null | tail -1 | tr -d ' ')

    if [ -z "$BUNDLER_VERSION" ]; then
        # No Gemfile.lock, install latest bundler
        print_info "Installing latest bundler..."
        if gem install bundler; then
            print_info "Bundler installed successfully"
        else
            print_warning "Failed to install bundler"
        fi
    else
        # Install specific bundler version
        print_info "Installing bundler version $BUNDLER_VERSION..."
        if gem install bundler -v "$BUNDLER_VERSION"; then
            print_info "Bundler $BUNDLER_VERSION installed successfully"
        else
            # Fallback to any bundler 2.x
            print_warning "Failed to install bundler $BUNDLER_VERSION, trying bundler 2.x"
            if gem install bundler -v '~> 2.0'; then
                print_info "Bundler 2.x installed successfully"
            else
                print_warning "Failed to install bundler"
            fi
        fi
    fi

    if command -v bundle &> /dev/null; then
        if bundle install; then
            cd - > /dev/null
            print_info "Ruby dependencies installed"
        else
            cd - > /dev/null
            print_warning "Failed to install Ruby dependencies"
            print_warning "You can install them manually later:"
            print_warning "  cd $GEMFILE_DIR && bundle install"
        fi
    else
        # Try to install bundler
        if command -v gem &> /dev/null; then
            print_info "Installing bundler..."
            if gem install bundler; then
                if bundle install; then
                    cd - > /dev/null
                    print_info "Ruby dependencies installed"
                else
                    cd - > /dev/null
                    print_warning "Failed to install Ruby dependencies"
                fi
            else
                cd - > /dev/null
                print_warning "Failed to install bundler"
            fi
        else
            cd - > /dev/null
            print_warning "Ruby not found. Please install Ruby first"
        fi
    fi
elif [ "$SKIP_BUNDLE" = true ]; then
    print_info "Skipping bundle install as requested"
fi

# Create initial config.json
CONFIG_CREATED=false

if [ -f "rjui_tools/bin/rjui" ]; then
    RJUI_BIN="rjui_tools/bin/rjui"
    print_info "Checking for React project..."

    # Search for package.json files in current and parent directories
    SEARCH_DIR="$(pwd)"
    FOUND_PACKAGE=""
    MAX_LEVELS=5
    CURRENT_LEVEL=0

    while [ $CURRENT_LEVEL -lt $MAX_LEVELS ] && [ -z "$FOUND_PACKAGE" ]; do
        if [ -f "$SEARCH_DIR/package.json" ]; then
            # Check if it's a React project
            if grep -q '"react"' "$SEARCH_DIR/package.json" 2>/dev/null; then
                FOUND_PACKAGE="$SEARCH_DIR"
                print_info "Found React project: $FOUND_PACKAGE"
                break
            fi
        fi
        SEARCH_DIR="$(dirname "$SEARCH_DIR")"
        CURRENT_LEVEL=$((CURRENT_LEVEL + 1))
    done

    if [ -n "$FOUND_PACKAGE" ]; then
        print_info "Creating initial configuration..."

        if $RJUI_BIN init 2>/dev/null; then
            CONFIG_CREATED=true
            print_info "Initial configuration created"
        else
            print_warning "Failed to create initial configuration"
            print_warning "You can create it manually later with:"
            print_warning "  $RJUI_BIN init"
        fi
    else
        print_warning "No React project found in parent directories"
        print_warning "After moving to your React project directory, run:"
        print_warning "  $RJUI_BIN init"
    fi
fi

print_info ""
print_info "Installation completed successfully!"
print_info ""
print_info "Next steps:"

if [ -d "rjui_tools" ]; then
    print_info "1. Add rjui_tools/bin to your PATH or use the full path"
    print_info "2. Run 'rjui init' to create configuration (if not done)"
    print_info "3. Run 'rjui setup' to set up your React project"
    print_info "4. Run 'rjui generate' to generate React components"
    print_info "5. Run 'rjui help' to see available commands"
fi

print_info ""
print_info "For more information, visit: https://github.com/$GITHUB_REPO"
