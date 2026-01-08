# ConfigurationError

`class`

*Defined in [src/ralph/errors.cr:45](https://github.com/watzon/ralph/blob/main/src/ralph/errors.cr#L45)*

Raised when Ralph is not properly configured

## Common Causes

- Accessing database before calling `Ralph.configure`
- Invalid database URL
- Missing database driver

