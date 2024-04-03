# frozen_string_literal: true

require_relative "spec_helper"

describe AttributeGuard do
  describe "lock_attributes" do
    it "return the names of the locked attributes" do
      expect(GenericModel.locked_attribute_names).to match_array(["name"])
      expect(TestModel.locked_attribute_names).to match_array ["name"]
      expect(TestModelSubclass.locked_attribute_names).to match_array ["name", "value", "foo", "bar", "baz", "bip"]
      expect(UnlockedModel.locked_attribute_names).to match_array []
    end
  end

  describe "attribute_locked?" do
    it "is false for attibutes that are not locked" do
      record = TestModel.create!(name: "test", value: 1)
      expect(record.attribute_locked?(:value)).to be false
    end

    it "is true for locked attributes" do
      record = TestModel.create!(name: "test", value: 1)
      expect(record.attribute_locked?(:name)).to be true
    end

    it "is false for locked attributes on new records" do
      record = TestModel.new(name: "test", value: 1)
      expect(record.attribute_locked?(:name)).to be false
    end

    it "is false if the attribute is explicitly unlocked" do
      record = TestModel.create!(name: "test", value: 1)
      record.unlock_attributes(:name)
      expect(record.attribute_locked?(:name)).to be false
      record.reload
      expect(record.attribute_locked?(:name)).to be false
      record.clear_unlocked_attributes
      expect(record.attribute_locked?(:name)).to be true
    end

    it "is false if the attribute is explicitly unlocked in a block" do
      record = TestModelSubclass.create!(name: "test", value: 1)
      record.unlock_attributes(:name) do
        expect(record.attribute_locked?(:name)).to be false
        expect(record.attribute_locked?(:value)).to be true

        record.unlock_attributes(:value) do
          expect(record.attribute_locked?(:name)).to be false
          expect(record.attribute_locked?(:value)).to be false
        end

        expect(record.attribute_locked?(:name)).to be false
        expect(record.attribute_locked?(:value)).to be true
      end
      expect(record.attribute_locked?(:name)).to be true
      expect(record.attribute_locked?(:value)).to be true
    end
  end

  describe "unlock_attributes" do
    it "returns self when called without a block" do
      record = TestModel.create!(name: "test", value: 1)
      expect(record.unlock_attributes(:name)).to be record
    end

    it "returns the result of the block when called with a block" do
      record = TestModel.create!(name: "test", value: 1)
      expect(record.unlock_attributes(:name) { 1 }).to be record
    end
  end

  describe "persistence" do
    it "allows creating records with locked attributes" do
      record = TestModel.new(name: "test", value: 1)
      expect { record.save!(name: "test", value: 1) }.to_not raise_error
    end

    it "allows updating records with no locked attributes" do
      record = UnlockedModel.create!(name: "test", value: 1)
      expect { record.update!(name: "test2", value: 2) }.to_not raise_error
    end

    it "is valid if a locked attribute does not change" do
      record = TestModel.create!(name: "test", value: 1)
      record.name = "test"
      expect(record.valid?).to be true
    end

    it "is valid if an unlocked attribute changes" do
      record = TestModel.create!(name: "test", value: 1)
      record.value = 2
      expect(record.valid?).to be true
    end

    it "adds a validation error if an attribute is not changeable" do
      record = TestModel.create!(name: "test", value: 1)
      record.name = "test2"
      expect(record.valid?).to be false
      expect(record.errors[:name]).to eq ["is locked and cannot be changed"]
    end

    it "adds a validation error with a custom message if an attribute is not changeable" do
      record = TestModelSubclass.create!(name: "test", value: 1)
      record.value = 2
      expect(record.valid?).to be false
      expect(record.errors[:value]).to eq ["Value cannot be changed message"]
    end

    it "raises an error in strict mode" do
      record = TestModelSubclass.create!(name: "test", value: 1, bip: 2)
      record.bip = 3
      expect { record.valid? }.to raise_error(ActiveModel::StrictValidationFailed)
    end

    it "logs a warning if the mode is set to :warn" do
      record = TestModelSubclass.create!(name: "test", foo: 1)
      record.foo = 2
      TestModelSubclass.logger_output.rewind
      expect(record.valid?).to be true
      expect(TestModelSubclass.logger_output.string).to include "Changed locked attribute foo on TestModelSubclass with id #{record.id}"
    end

    it "calls a custom proc in the validator if one is provided as the mode" do
      record = TestModelSubclass.create!(name: "test", baz: 1)
      record.baz = 2
      expect(record.valid?).to be false
      expect(record.errors[:baz]).to eq ["Custom error"]
    end
  end
end
