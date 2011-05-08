require "open-uri"
require "fileutils"
require "logger"
require "erb"

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
    logger.info "GET #{env["PATH_INFO"]}"
    if env["PATH_INFO"] == "/list"
      [200, {"Content-Type" => "text/html"}, [listing]]
    else
      [200, {"Content-Type" => "application/octet-stream"}, [contents]]
    end
  rescue Exception => error
    # Just try to load from file if something goes wrong.
    # This includes HTTP timeout, or something.
    # If it fails again, we won't have any files anyway!
    logger.error "Error: #{error.class} => #{error.message}"
    if File.exists?(filepath)
      content = open(filepath).read
      [200, {"Content-Type" => "application/octet-stream"}, [content]]
    else
      content = open(File.expand_path("../public/404.html", __FILE__))
      [404, {"Content-Type" => "text/html"}, [content]]
    end
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

  def listing
    last_gem = ""
    gem_versions = []
    @gem_list = []
    Dir.glob(File.expand_path("../cache/gems/*.gem", __FILE__)).sort.each do |file| 
      file = File.basename(file)
      if file =~ /^(.*?)\-(\d+.*?)\.gem$/
        if last_gem != $1
          @gem_list << { :name => last_gem, :versions => gem_versions } unless last_gem == ""
          gem_versions = [$2]
          last_gem = $1
        else
          gem_versions << $2
        end
      end
    end
    rhtml = ERB.new(File.read(File.expand_path("../list.erb", __FILE__)), nil, "%")
    rhtml.result(binding)
  end

  def contents
    if cached? && !specs?
      logger.info "Read from cache: #{filepath}"
      open(filepath).read
    else
      logger.info "Read from interwebz: #{url}"
      open(url).read.tap {|content| save(content)}
    end
  end

  def save(contents)
    FileUtils.mkdir_p File.dirname(filepath)
    File.open(filepath, "wb") {|handler| handler << contents}
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

