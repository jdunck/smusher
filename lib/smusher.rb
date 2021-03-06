require 'rubygems'
require 'rake'
require 'json'
require 'open-uri'
require 'httpclient'

module Smusher
  extend self

  MINIMUM_IMAGE_SIZE = 20#byte

  # optimize the given image
  # converts gif to png, if size is lower
  # can be called with a file-path or an array of files-paths
  def optimize_image(files,options={})
    files.each do |file|
      check_options(options)
      puts "THIS FILE IS EMPTY!!! #{file}" and return if size(file).zero?
      success = false

      with_logging(file,options[:quiet]) do
        write_optimized_data(file)
        success = true
      end

      if success
        gif = /\.gif$/
        `mv #{file} #{file.sub(gif,'.png')}` if file =~ gif
      end
    end
  end

  # fetch all jpg/png images from  given folder and optimize them
  def optimize_images_in_folder(folder,options={})
    check_options(options)
    images_in_folder(folder,options[:convert_gifs]).each do |file|
      optimize_image(file)
    end
  end

private

  def check_options(options)
    known_options = [:convert_gifs,:quiet]
    if options.detect{|k,v| not known_options.include?(k)}
      raise "Known options: #{known_options*' '}"
    end
  end

  def write_optimized_data(file)
    optimized = optimized_image_data_for(file)

    raise "Error: got larger" if size(file) < optimized.size
    raise "Error: empty file downloaded" if optimized.size < MINIMUM_IMAGE_SIZE
    raise "cannot be optimized further" if size(file) == optimized.size

    File.open(file,'w') {|f| f.puts optimized}
  end

  def sanitize_folder(folder)
    folder.sub(%r[/$],'')#remove tailing slash
  end

  def images_in_folder(folder,with_gifs=false)
    folder = sanitize_folder(folder)
    images = %w[png jpg jpeg JPG]
    images << 'gif' if with_gifs
    images.map! {|ext| "#{folder}/**/*.#{ext}"}
    FileList[*images]
  end

  def size(file)
    File.exist?(file) ? File.size(file) : 0
  end

  def with_logging(file,quiet)
    puts "smushing #{file}" unless quiet

    before = size(file)
    begin; yield; rescue; puts $! unless quiet; end
    after = size(file)

    unless quiet
      result = "#{(100*after)/before}%"
      puts "#{before} -> #{after}".ljust(40) + " = #{result}"
      puts ''
    end
  end

  def optimized_image_data_for(file)
    response = JSON.parse((HTTPClient.post 'http://smush.it/ws.php', { 'files[]' => File.new(file) }).body.content)
    raise "smush.it: #{response['error']}" if response['error']
    path = response['dest']
    raise "no dest path found" unless path
    open("http://smush.it/#{path}") { |source| source.read() }
  end
end
