require "open-uri"
require "fileutils"
require "logger"
require "erb"

module Proxy
  # we don't want to instantiate this class - it's a singleton,
  # so just keep it as a self-extended module
  extend self

  # Appdata provides a basic single-method DSL with .parameter method
  # being used to define a set of available settings.
  # This method takes one or more symbols, with each one being
  # a name of the configuration option.
  def parameter(*names)
    names.each do |name|
      attr_accessor name

      # For each given symbol we generate accessor method that sets option's
      # value being called with an argument, or returns option's current value
      # when called without arguments
      define_method name do |*values|
        value = values.first
        value ? self.send("#{name}=", value) : instance_variable_get("@#{name}")
      end
    end
  end

  # And we define a wrapper for the configuration block, that we'll use to set up
  # our set of options
  def config(&block)
    instance_eval &block
  end

end

Proxy.config do
  parameter :http_proxy_url
  parameter :http_proxy_user
  parameter :http_proxy_pass
  parameter :spec_expiry_time
end

require './config'

class RubygemsProxy
  attr_reader :env

  def self.call(env)
    new(env).run
  end

  def initialize(env)
    @env = env
    logger.level = Logger::INFO
  end

  def run
    logger.info "#{env["REQUEST_METHOD"]} #{env["PATH_INFO"]}"

    return update_specs if env["REQUEST_METHOD"] == "DELETE"

    case env["PATH_INFO"]
    when "/"
      [200, {"Content-Type" => "text/html"}, [erb(:index)]]
    else
      [200, {"Content-Type" => "application/octet-stream"}, [contents]]
    end
  rescue Exception
    [200, {"Content-Type" => "text/html"}, [erb(404)]]
  end

  private
  def erb(view)
    ERB.new(template(view)).result(binding)
  end

  def server_url
    env["rack.url_scheme"] + "://" + File.join(env["SERVER_NAME"], env["PATH_INFO"])
  end

  def rubygems_url(gemname)
    "http://rubygems.org/gems/%s" % Rack::Utils.escape(gemname)
  end

  def gem_url(name, version)
    File.join(server_url, "gems", Rack::Utils.escape("#{name}-#{version}.gem"))
  end

  def gem_list
    Dir[File.dirname(__FILE__) + "/public/gems/**/*.gem"]
  end

  def grouped_gems
    gem_list.inject({}) do |buffer, file|
      basename = File.basename(file)
      parts = basename.gsub(/\.gem/, "").split("-")
      version = parts.pop
      name = parts.join("-")

      buffer[name] ||= []
      buffer[name] << version
      buffer
    end
  end

  def template(name)
    @templates ||= {}
    @templates[name] ||= File.read(File.dirname(__FILE__) + "/views/#{name}.erb")
  end

  def root_dir
    File.expand_path "..", __FILE__
  end

  def logger
    @logger ||= Logger.new("#{root_dir}/tmp/server.log", 10, 1024000)
  end

  def cache_dir
    "#{root_dir}/public"
  end

  def contents
    if File.directory?(filepath)
      erb(404)
    elsif cached?
      logger.info "Read from cache: #{filepath}"
      open(filepath).read
    else
      logger.info "Read from interwebz: #{url}"
      proxy_args = { }
      unless ::Proxy.http_proxy_url.nil?
        logger.info "Using proxy:#{::Proxy.http_proxy_url}"
        unless ::Proxy.http_proxy_user.nil?
          logger.info "HTTP Proxy authentication enabled. Using user:#{::Proxy_http_proxy_user}"
          proxy_args = { :proxy_http_basic_authentication => [::Proxy.http_proxy_url, ::Proxy.http_proxy_user, ::Proxy.http_proxy_pass]}
        else
          logger.info "Using proxy without authentication."
          proxy_args = { :proxy => ::Proxy.http_proxy_url }
        end
      end
      open(url, proxy_args).read.tap {|content| save(content)}
    end
  rescue Exception => error
    # Just try to load from file if something goes wrong.
    # This includes HTTP timeout, or something.
    # If it fails again, we won't have any files anyway!
    logger.error "Error: #{error.class} => #{error.message}"
    open(filepath).read
  end

  def save(contents)
    FileUtils.mkdir_p File.dirname(filepath)
    File.open(filepath, "wb") {|handler| handler << contents}
  end

  def cached?
    case File.basename(filepath)
    when /^specs\./
      File.exist?(filepath) && (Time.now - File.mtime(filepath)).to_i < ::Proxy.spec_expiry_time
    when /\.gz$/
      false
    else
      File.file?(filepath)
    end
  end

  def specs?
    env["PATH_INFO"] =~ /specs\..+\.gz$/
  end

  def filepath
    if specs?
      File.join(root_dir, env["PATH_INFO"])
    else
      File.join(cache_dir, env["PATH_INFO"])
    end
  end

  def url
    File.join("http://rubygems.org", env["PATH_INFO"])
  end

  def update_specs
    Dir[File.dirname(__FILE__) + "/*.gz"].each {|file| File.unlink(file)}
    [200, {"Content-Type" => "text/plain"}, [""]]
  end
end
