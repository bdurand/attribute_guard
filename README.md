# Active Record Attribute Guard

[![Continuous Integration](https://github.com/bdurand/attribute_guard/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/attribute_guard/actions/workflows/continuous_integration.yml)
[![Regression Test](https://github.com/bdurand/attribute_guard/actions/workflows/regression_test.yml/badge.svg)](https://github.com/bdurand/attribute_guard/actions/workflows/regression_test.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
[![Gem Version](https://badge.fury.io/rb/attribute_guard.svg)](https://badge.fury.io/rb/attribute_guard)

This Ruby gem provides an extension for ActiveRecord/ActiveModel allowing you to declare certain attributes in a model to be locked. Locked attributes cannot be changed once a record is created unless you explicitly allow changes.

This feature can be used for a couple of different purposes.

1. Preventing changes to data that should be immutable.
2. Prevent direct data updates that bypass required business logic.

## Usage

### Declaring Locked Attributes

To declare locked attributes you simply need to include the `AttributeGuard` module into your model and then list the attributes with the `lock_attributes` method.

```ruby
class MyModel < ApplicationRecord
  include AttributeGuard

  lock_attributes :created_by, :created_at
end
```

Once that is done, if you try to change a locked value on an existing record, you will get a validation error.

```ruby
record = MyModel.last
record.created_at = Time.now
record.save! # => raises ActiveRecord::RecordInvalid
```

You can customize the validation error message by setting the value of the `errors.messages.locked` value in your i18n localization files. You can also specify an error message with the optional `error` keyword argument.

```ruby
class MyModel < ApplicationRecord
  include AttributeGuard

  lock_attributes :created_by, error: "cannot be changed except by an admin"
end
```

### Unlocking Attributes

You can allow changes to locked attributes with the `unlock_attributes` method.

```ruby
record = MyModel.last
record.unlock_attributes(:created_at, :created_by)
record.update!(created_at: Time.now, created_by: nil) # Changes are persisted
```

You can also supply a block to `unlock_attributes` which will clear any unlocked attributes when the block exits.

```ruby
record = MyModel.last
record.unlock_attributes(:created_at) do
  record.update!(created_at: Time.now) # Changes are persisted
end

record.update!(created_at: Time.now) # => raises ActiveRecord::RecordInvalid
```

The `unlock_attributes` method will return the record itself, so you can chain other instance methods off of it.

```ruby
record.unlock_attributes(:created_at).update!(created_at: Time.now)
```

### Using As A Guard

You can use locked attributes as a guard to prevent direct updates to certain attributes and force changes to go through specific methods instead.

For example, suppose we have some business logic that needs to execute whenever the `status` field is changed. You might wrap that logic up into a method or service object. For this example, suppose that we want to send some kind of alert any time the status is changed.

```ruby
class MyModel
  def update_status(new_status)
    update!(status: new_status)
    StatusAlert.new(self).send_status_changed_alert
  end
end

record = MyModel.last
record.update_status("completed")
```

This has the risk, though, that you can still make direct updates to the `status` which would bypass the additional business logic.

```ruby
record = MyModel.last
record.update!(status: "canceled") # StatusAlert method is not called.
```

You can prevent this by locking the `status` attribute and then unlocking it within the method that includes the required business logic.

```ruby
class MyModel
  include AttributeGuard

  lock_attributes :status

  def update_status(new_status)
    unlock_attributes(:status) do
      update!(status: new_status)
    end
    StatusAlert.new(self).send_status_changed_alert
  end
end

record = MyModel.last
record.update_status("completed") # Status gets updated
record.update!(status: "canceled") # raises ActiveRecord::RecordInvalid error
```

### Modes

The default behavior when a locked attribute is changed is to add a validation error to the record. You can change this behavior with the `mode` option when locking attributes. You still need to validate the record to trigger the locked attribute check, regardless of the mode.

```ruby
class MyModel
  include AttributeGuard

  lock_attributes :email, mode: :error
  lock_attributes :name: mode: :warn
  lock_attributes :updated_at, mode: :raise
  lock_attributes :created_at, mode: ->(record, attribute) { raise "Created timestamp cannot be changed" }
end
```

* `:error` - Add a validation error to the record. This is the default.

* `:warn` - Log a warning that the record was changed. This mode is useful to allow you soft deploy locked attributes to production on a mature project and give you information about where you may need to update code to unlock attributes. If the model does not have a `logger` method that returns a `Logger`-like object, then the output will be sent to `STDERR`.

* `:raise` = Raise an `AttributeGuard::LockedAttributeError` error.

* `Proc` - If you provide a `Proc` object, it will be called with the record and the attribute name when a locked attribute is changed.

### Using with ActiveModel

The gem works out of the box with ActiveRecord. You can also use it with ActiveModel classes as long as they include the `ActiveModel::Validations` and `ActiveModel::Dirty` modules. The model also needs to implement a `new_record?` method.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "attribute_guard"
```

Then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install attribute_guard
```

## Contributing

Open a pull request on [GitHub](https://github.com/bdurand/attribute_guard).

Please use the [standardrb](https://github.com/testdouble/standard) syntax and lint your code with `standardrb --fix` before submitting.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
