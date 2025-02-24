# Contributing to Shell Scripts Library

Thank you for your interest in contributing to the Shell Scripts Library! We welcome bug fixes, improvements, new features, documentation updates, and other enhancements. By participating in this project, you agree to abide by our guidelines and the [Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

### 1. Reporting Issues

If you find a bug or have a suggestion for improvement, please check the [issue tracker](https://github.com/a4abhishek/shell-scripts/issues) first to see if it has already been reported. If not, open a new issue and include:
- A clear title and description
- Steps to reproduce the issue (if applicable)
- Any relevant error messages or screenshots

### 2. Suggesting Enhancements

We welcome ideas for new features or improvements! Please open an issue with a detailed description of your suggestion and how it would benefit users of the library.

### 3. Pull Requests

Before submitting a pull request (PR), please:

- **Fork the repository** and create a feature branch from `main`.
- Ensure your branch name is descriptive (e.g., `feature/add-input-method` or `bugfix/fix-logging-format`).
- Make sure your changes adhere to our coding and documentation guidelines.
- Write tests for new features or bug fixes where possible.
- **Run the test suite locally** (using `make test` or `./run_tests.sh`) to ensure that your changes do not break the build.
- Your PR description should be clear and concise, and reference any related issue numbers if applicable.

#### Pull Request Process

1. **Fork** the repository and clone your fork locally.
2. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Commit your changes** with clear, descriptive messages:
   ```bash
   git commit -m "Add feature: description of your changes"
   ```
4. **Push** your branch to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
5. **Open a Pull Request** against the `main` branch on the original repository.

### 4. Coding Guidelines

- **Consistency:** Follow the existing code style. Look at the code in the `lib/` and `bin/` directories for examples.
- **Duplicate Prevention:** Use load guards in libraries to prevent multiple sourcing.
- **Documentation:** Update documentation and add comments where necessary.
- **Tests:** Ensure that new code is covered by tests. Use BATS for test scripts and run `make test` before submitting a PR.

### 5. Commit Message Guidelines

- Write clear and concise commit messages.
- Use the imperative mood (e.g., "Fix bug", "Add feature").
- Reference any related issues by including the issue number (e.g., `Fixes #42`).
- Keep commits atomic: each commit should represent a single logical change.
- Limit your commit subject line to around 50 characters, with the body wrapped at around 72 characters per line.

### 6. Testing

Before submitting a PR, please run the test suite using `make test` or `./run_tests.sh`. Ensure that all tests pass and there are no warnings or errors.

### 7. Code of Conduct

Please review our [Code of Conduct](CODE_OF_CONDUCT.md) before contributing. We strive to create a welcoming and respectful community for everyone.

---

We appreciate your contributions to making the Shell Scripts Library better for everyone. If you have any questions or need assistance, please feel free to reach out via the issue tracker or our community channels.

Happy scripting!
