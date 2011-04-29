require "open-uri"
require "fileutils"
require "logger"

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
    [200, {"Content-Type" => "application/octet-stream"}, [contents]]
  end

  private
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
    if cached? && valid?
      logger.info "Read from cache: #{filepath}"
      open(filepath).read
    else
      logger.info "Read from interwebz: #{url}"
      open(url).read.tap {|content| save(content)}
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

  def valid?
    specs? ? Time.now - File.mtime(filepath) < 300 : true
  end

  def specs?
    env["PATH_INFO"] =~ /specs\..+\.gz$/
  end

  def cached?
    File.file?(filepath)
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
end
