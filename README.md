# shrine-storage-azure-blob

`shrine-storage-azure-blob` is a Shrine storage adapter for Azure Blob Storage.

It supports:

- direct uploads via short-lived SAS URLs
- signed private read URLs
- configurable container prefixes such as `cache/` and `store/`
- private or public URL generation

This adapter is built on top of the [`azure-blob`](https://rubygems.org/gems/azure-blob) gem.

## Installation

Add the gem to your application's `Gemfile`:

```ruby
gem "shrine-storage-azure-blob", "~> 0.1.0"
```

Then install dependencies:

```bash
bundle install
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install shrine-storage-azure-blob
```

## Usage

Require the adapter:

```ruby
require "shrine/storage/azure_blob"
```

Configure Shrine storages:

```ruby
Shrine.storages = {
  cache: Shrine::Storage::AzureBlob.new(
    account_name: ENV.fetch("STORAGE_ACCOUNT_NAME"),
    access_key: ENV.fetch("STORAGE_ACCESS_KEY"),
    container: ENV.fetch("STORAGE_CONTAINER", "uploads"),
    prefix: "cache"
  ),
  store: Shrine::Storage::AzureBlob.new(
    account_name: ENV.fetch("STORAGE_ACCOUNT_NAME"),
    access_key: ENV.fetch("STORAGE_ACCESS_KEY"),
    container: ENV.fetch("STORAGE_CONTAINER", "uploads"),
    prefix: "store"
  )
}
```

### Direct uploads

Use `#presign` to generate a short-lived SAS URL for browser uploads:

```ruby
presign = Shrine.storages[:cache].presign(
  "example.png",
  content_type: "image/png",
  metadata: { filename: "example.png" }
)
```

The return value is a hash with:

- `:method`
- `:url`
- `:headers`

The browser should upload the file directly to the returned Azure Blob URL with the returned headers.

### Private file URLs

By default, `#url` returns a signed private read URL:

```ruby
Shrine.storages[:store].url("avatars/user.png")
```

To generate public URLs instead, initialize the storage with `public: true`.

### Container creation

The adapter exposes `#ensure_container!`:

```ruby
Shrine.storages[:cache].ensure_container!
```

That is useful for bootstrapping empty environments, but in most deployments container creation should be handled by infrastructure or a deployment task.

### Initialization options

Supported initializer options:

- `account_name:` Azure Storage Account name
- `access_key:` Azure Storage Account access key
- `container:` blob container name
- `prefix:` optional blob key prefix
- `host:` optional blob host override
- `public:` if `true`, `#url` returns unsigned public URLs

Additional keyword arguments are forwarded to `AzureBlob::Client`.

## Notes

- This adapter currently uses account key authentication.
- Upload presigning uses Azure SAS URLs with create/write permissions.
- Private read URLs use signed SAS URLs with read permission.
- `ActionDispatch::Http::ContentDisposition` is used to format download disposition headers, so `actionpack` is a runtime dependency.

## Development

After checking out the repo, run:

```bash
bin/setup
bundle exec rake test
```

You can also run:

```bash
bin/console
```

to experiment with the adapter interactively.

To install this gem locally:

```bash
bundle exec rake install
```

To release a new version:

1. Update the version in `lib/shrine/storage/azure_blob/version.rb`
2. Commit the change
3. Run:

```bash
bundle exec rake release
```

## Contributing

Bug reports and pull requests are welcome on GitHub:

- https://github.com/galiyafatt2/shrine-storage-azure-blob

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
