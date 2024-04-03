# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 1.1.0

### Added

- Added :raise mode that raises an error if a locked attribute has been changed instead of adding a validation error.

### Changed

- Changed gem dependency from `activerecord` to `activemodel`. You can now use locked attributes with ActiveModel classes that include `ActiveModel::Validations` and `ActiveModel::Dirty and implement a `new_record?` method.

## 1.0.1

### Added
- Optimize object shapes for the Ruby interpreter by declaring instance variables in constructors.

## 1.0.0

### Added
- Initial release.
