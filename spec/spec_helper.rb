# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])

begin
  require "simplecov"
  SimpleCov.start do
    add_filter ["/spec/", "/app/", "/config/", "/db/"]
  end
rescue LoadError
end

Bundler.require(:default, :test)

require "active_model"

require_relative "../lib/attribute_guard"

class BaseModel
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations
  include ActiveModel::Dirty
  include AttributeGuard

  class << self
    def logger_output
      @logger_output ||= StringIO.new
    end

    def logger
      @logger ||= Logger.new(logger_output)
    end

    def create(attributes = {})
      record = new(attributes)
      record.save
      record
    end

    def define_attribute(name, type = :string)
      attribute name, type

      attr_reader name

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{name}=(value)
          #{name}_will_change! unless value == @#{name}
          @#{name} = value
        end
      RUBY
    end
  end

  define_attribute :id, :integer
  define_attribute :name, :string
  define_attribute :value, :integer
  define_attribute :foo, :string
  define_attribute :bar, :integer
  define_attribute :baz, :integer
  define_attribute :bip, :integer

  def logger
    BaseModel.logger
  end

  def save
    if valid?
      changes_applied
      self.id ||= rand(1_000_000_000)
      true
    else
      false
    end
  end

  def new_record?
    id.nil?
  end
end

class TestModel < BaseModel
  lock_attributes :name
end

class TestModelSubclass < TestModel
  lock_attributes :value, error: "Value cannot be changed message"
  lock_attributes :foo, :bar, mode: :warn
  lock_attributes :baz, mode: ->(record, attribute) { record.errors.add(attribute, "Custom error") }
  lock_attributes :bip, mode: :raise
end

class UnlockedModel < BaseModel
end
