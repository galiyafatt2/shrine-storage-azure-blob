# frozen_string_literal: true

require "test_helper"
require "stringio"
require "uri"

class Shrine::Storage::AzureBlobTest < Minitest::Test
  def setup
    @client = mock("azure-client")
    ::AzureBlob::Client.stubs(:new).returns(@client)

    @storage = Shrine::Storage::AzureBlob.new(
      account_name: "sanestdev",
      access_key: "secret",
      container: "uploads",
      prefix: "cache"
    )
  end

  def test_presign_returns_azure_upload_url_and_headers
    signed_uri = URI("https://sanestdev.blob.core.windows.net/uploads/cache/test-file.webp?sig=123")
    @client.expects(:signed_uri).with("cache/test-file.webp", has_entries(permissions: "cw")).returns(signed_uri)

    presign = @storage.presign(
      "test-file.webp",
      content_type: "image/webp",
      metadata: { filename: "test-file.webp" }
    )

    assert_equal "PUT", presign[:method]
    assert_equal signed_uri.to_s, presign[:url]
    assert_equal "BlockBlob", presign[:headers]["x-ms-blob-type"]
    assert_equal "image/webp", presign[:headers]["Content-Type"]
    assert_equal "test-file.webp", presign[:headers]["x-ms-meta-filename"]
  end

  def test_url_signs_private_read_access
    signed_uri = URI("https://sanestdev.blob.core.windows.net/uploads/store/avatar.png?sig=read")
    @client.expects(:signed_uri).with("cache/avatar.png", has_entries(permissions: "r")).returns(signed_uri)

    assert_equal signed_uri.to_s, @storage.url("avatar.png")
  end

  def test_upload_prefixes_keys_and_passes_mime_metadata
    io = StringIO.new("content")
    @client.expects(:create_block_blob).with(
      "cache/file.png",
      io,
      has_entries(
        content_type: "image/png",
        metadata: { "filename" => "file.png" }
      )
    )

    @storage.upload(io, "file.png", shrine_metadata: { "mime_type" => "image/png", "filename" => "file.png" })
  end

  def test_url_returns_public_uri_without_signing
    public_storage = Shrine::Storage::AzureBlob.new(
      account_name: "sanestdev",
      access_key: "secret",
      container: "uploads",
      prefix: "store",
      public: true
    )
    public_uri = URI("https://sanestdev.blob.core.windows.net/uploads/store/avatar.png")
    @client.expects(:generate_uri).with("uploads/store/avatar.png").returns(public_uri)
    @client.expects(:signed_uri).never

    assert_equal public_uri.to_s, public_storage.url("avatar.png")
  end

  def test_exists_delegates_to_client
    @client.expects(:blob_exist?).with("cache/avatar.png").returns(true)

    assert @storage.exists?("avatar.png")
  end

  def test_delete_ignores_missing_blobs
    @client.expects(:delete_blob).with("cache/avatar.png").raises(::AzureBlob::Http::FileNotFoundError)

    assert_nil @storage.delete("avatar.png")
  end

  def test_open_returns_binary_stringio
    @client.expects(:get_blob).with("cache/file.png", {}).returns("binary content")

    io = @storage.open("file.png")

    assert_instance_of StringIO, io
    assert_equal Encoding::BINARY, io.external_encoding
  end

  def test_open_raises_shrine_file_not_found_for_missing_blobs
    @client.expects(:get_blob).with("cache/missing.png", {}).raises(::AzureBlob::Http::FileNotFoundError, "not found")

    assert_raises(Shrine::FileNotFound) { @storage.open("missing.png") }
  end
end
