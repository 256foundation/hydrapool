# Start9 CI/CD Workflows

This directory contains GitHub Actions workflows for building and testing the Hydra-Pool Start9 package.

## Workflows

### 1. Build Start9 Package (`build-start9.yml`)

**Triggers:**
- Push to `main` or `develop` branches
- Tags starting with `v*` (releases)
- Pull requests to `main`
- Manual workflow dispatch

**Features:**
- Multi-architecture builds (AMD64, ARM64)
- Rust dependency caching
- Start9 package creation and verification
- Docker image building and pushing
- Automatic GitHub releases for tags
- Artifact upload for testing

**Outputs:**
- `.s9pk` package files
- Docker images pushed to GitHub Container Registry
- GitHub releases with download links

### 2. Update Dependencies (`update-dependencies.yml`)

**Triggers:**
- Weekly schedule (Sundays at 2 AM UTC)
- Manual workflow dispatch

**Features:**
- Rust dependency updates (`cargo update`)
- Docker base image update checks
- Start SDK version verification
- Automated pull request creation
- Build testing after updates

## Usage

### Manual Package Build

You can manually trigger a package build:

1. Go to **Actions** tab in GitHub
2. Select **Build Start9 Package**
3. Click **Run workflow**
4. Optionally specify version and release settings

### Testing Changes

When making changes to the Start9 package:

1. Create a feature branch
2. Make your changes
3. Push to trigger automatic testing
4. Review test results before merging

### Release Process

To create a new release:

1. Update version in `Cargo.toml`
2. Create a git tag: `git tag v1.2.3`
3. Push the tag: `git push origin v1.2.3`
4. GitHub Actions will automatically:
   - Build the package
   - Create a GitHub release
   - Upload `.s9pk` file
   - Push Docker images

## Configuration

### Required Secrets

The workflows use these GitHub repository secrets:

- `GITHUB_TOKEN`: Automatically provided by GitHub Actions
- No additional secrets required for basic functionality

### Environment Variables

Key environment variables used:

- `REGISTRY`: GitHub Container Registry (`ghcr.io`)
- `IMAGE_NAME`: Repository name (`${{ github.repository }}`)
- `PKG_VERSION`: Extracted from `Cargo.toml` or workflow input

## Artifacts

### Build Artifacts

- **Package Files**: `.s9pk` files for Start9 installation
- **Docker Images**: Multi-architecture images in GHCR
- **Test Results**: Configuration and script validation results

### Retention

- Build artifacts: 30 days
- Test artifacts: 7 days
- Releases: Permanent (GitHub releases)

## Troubleshooting

### Common Issues

1. **Build Failures**: Check Rust version compatibility (requires 1.88.0+)
2. **Docker Build Issues**: Verify Dockerfile syntax and base image availability
3. **Package Verification**: Ensure all required files are present in `start9/` directory
4. **Release Failures**: Check tag format and version consistency

### Debug Steps

1. Review workflow logs for specific error messages
2. Check artifact downloads for incomplete packages
3. Verify Start SDK installation and version
4. Test locally with `make build` and `make pack`

### Local Development

To test workflows locally:

```bash
# Install required tools
curl -L https://github.com/Start9Labs/start-sdk/releases/latest/download/start-sdk-linux-x86_64.tar.gz | tar xz
sudo mv start-sdk /usr/local/bin/

# Test package creation
cd start9
make build
make pack
make verify
```

## Contributing

When adding new workflows or modifying existing ones:

1. Follow existing naming conventions
2. Use appropriate triggers and permissions
3. Include comprehensive error handling
4. Add clear documentation
5. Test thoroughly before merging

For more information, see the [GitHub Actions documentation](https://docs.github.com/en/actions).
