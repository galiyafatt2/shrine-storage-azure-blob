# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "shrine/storage/azure_blob"

require "minitest/autorun"
require "mocha/minitest"
