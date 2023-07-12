# Unified Application Configuration :construction:

[![Continuous Integration](https://github.com/bdurand/attribute_guard/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/attribute_guard/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)

This Ruby gem provides an extension for ActiveRecord allowing you to declare certain attributes in a model to be locked. Locked attributes cannot be changed once a record is created unless you explicitly allow changes.

This feature can be used for a couple of different purposes.

1. Preventing changes to data that should be immutable.
2. Adding a guard to prevent direct data updates that bypass required business logic.

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

```
record = MyModel.last
record.unlock_attributes(:created_at, :created_by)
record.update!(created_at: Time.now, created_by: nil) # Changes are persisted
```

You can also supply a block to `unlock_attributes` which will clear any unlocked attributes when the block exits.

```
record = MyModel.last
record.unlock_attributes(:created_at) do
  record.update!(created_at: Time.now) # Changes are persisted
end

record.update!(created_at: Time.now) # => raises ActiveRecord::RecordInvalid
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
