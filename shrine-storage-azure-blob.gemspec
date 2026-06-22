# frozen_string_literal: true

require_relative "lib/shrine/storage/azure_blob/version"

Gem::Specification.new do |spec|
  spec.name = "shrine-storage-azure-blob"
  spec.version = Shrine::Storage::AzureBlob::VERSION
  spec.authors = ["Galiia Fattakhova"]
  spec.email = ["elizabeth.mor324@gmail.com"]

  spec.summary = "Azure Blob Storage adapter for Shrine"
  spec.description = "Provides a Shrine storage adapter for Azure Blob Storage with signed upload and download URLs."
  spec.homepage = "https://github.com/galiyafatt2/shrine-storage-azure-blob"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "actionpack", ">= 7.0", "< 9.0"
  spec.add_dependency "azure-blob", "~> 0.8.0"
  spec.add_dependency "shrine", ">= 3.0", "< 4.0"

  spec.add_development_dependency "mocha", "~> 2.0"
end
