# frozen_string_literal: true

require "active_support/concern"
require "active_support/lazy_load_hooks"
require "active_model/validator"

ActiveSupport.on_load(:i18n) do
  I18n.load_path << File.expand_path("locale/en.yml", __dir__)
end

# Extension for ActiveRecord models that adds the capability to lock attributes to prevent direct
# changes to them. This is useful for attributes that should only be changed through specific methods.
#
# @example
#   class User < ActiveRecord::Base
#     include AttributeGuard
#
#     lock_attributes :name, :email
#   end
#
#   user = User.create!(name: "Test", email: "test@example")
#   user.name = "Test 2"
#   user.save! # => raises ActiveRecord::RecordInvalid
#
#   user.unlock_attributes(:name)
#   user.name = "Test 2"
#   user.save! # => saves successfully
#
#   user.unlock_attributes(:name) do
#     user.name = "Test 3"
#     user.save! # => saves successfully
#   end
#
#   user.name = "Test 4"
#   user.save! # => raises ActiveRecord::RecordInvalid
module AttributeGuard
  extend ActiveSupport::Concern

  class LockedAttributeError < StandardError
  end

  included do
    class_attribute :locked_attributes, default: {}, instance_accessor: false
    private_class_method :locked_attributes=
    private_class_method :locked_attributes

    validates_with LockedAttributesValidator

    prepend Initializer
  end

  module Initializer
    def initialize(*)
      @unlocked_attributes = nil
      super
    end
  end

  # Validator that checks for changes to locked attributes.
  class LockedAttributesValidator < ActiveModel::Validator
    def validate(record)
      unless record.respond_to?(:new_record?)
        raise "AttributeGuard can only be used with models that respond to :new_record?"
      end

      return if record.new_record?

      record.class.send(:locked_attributes).each do |attribute, params|
        if record.changes.include?(attribute) && record.attribute_locked?(attribute)
          message, mode = params
          if mode == :warn
            log_warning(record, attribute)
          elsif mode == :raise
            raise LockedAttributeError.new(error_message(record, attribute))
          elsif mode.is_a?(Proc)
            mode.call(record, attribute)
          else
            record.errors.add(attribute, message)
          end
        end
      end
    end

    private

    def error_message(record, attribute)
      "Changed locked attribute #{attribute} on #{record.class.name} with id #{record.id}"
    end

    def log_warning(record, attribute)
      message = error_message(record, attribute)
      if record.respond_to?(:logger) && record.logger.respond_to?(:warn)
        record.logger.warn(message)
      else
        warn(message)
      end
    end
  end

  module ClassMethods
    # Locks the given attributes so that they cannot be changed directly. Subclasses inherit
    # the locked attributes from their parent classes.
    #
    # You can optionally specify a mode of what to do when a locked attribute is changed. The
    # default is to add an error to the model, but you can also specify :warn to log a warning
    # or a Proc to call with the record and attribute name.
    #
    # @param attributes [Array<Symbol, String>] the attributes to lock
    # @param error [String, Symbol, Boolean] the error message to use in validate errors
    # @param mode [Symbol, Proc] mode to use when a locked attribute is changed
    # @return [void]
    def lock_attributes(*attributes, error: :locked, mode: :error)
      locked = locked_attributes.dup
      error = error.dup.freeze if error.is_a?(String)

      attributes.flatten.each do |attribute|
        locked[attribute.to_s] = [error, mode]
      end

      self.locked_attributes = locked
    end

    # Returns the names of the locked attributes.
    #
    # @return [Array<String>] the names of the locked attributes.
    def locked_attribute_names
      locked_attributes.keys
    end
  end

  # Unlocks the given attributes so that they can be changed. If a block is given, the attributes
  # are unlocked only for the duration of the block.
  #
  # This method returns the object itself so that it can be chained.
  #
  # @example
  #   user.unlock_attributes(:email).update!(email: "user@example.com")
  #
  # @param attributes [Array<Symbol, String>] the attributes to unlock
  # @return [Object] the object itself
  def unlock_attributes(*attributes)
    attributes = attributes.flatten.map(&:to_s)
    return if attributes.empty?

    @unlocked_attributes ||= Set.new

    if block_given?
      save_val = @unlocked_attributes
      begin
        @unlocked_attributes = @unlocked_attributes.dup.merge(attributes)
        yield
      ensure
        @unlocked_attributes = save_val
        clear_unlocked_attributes if @unlocked_attributes.empty?
      end
    else
      @unlocked_attributes.merge(attributes)
    end

    self
  end

  # Returns true if the given attribute is currently locked.
  #
  # @param attribute [Symbol, String] the attribute to check
  # @return [Boolean] whether the attribute is locked
  def attribute_locked?(attribute)
    return false if new_record?

    attribute = attribute.to_s
    return false unless self.class.send(:locked_attributes).include?(attribute)

    return true if @unlocked_attributes.nil?

    !@unlocked_attributes.include?(attribute.to_s)
  end

  # Clears any unlocked attributes.
  #
  # @return [void]
  def clear_unlocked_attributes
    @unlocked_attributes = nil
  end
end
