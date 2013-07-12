require 'singleton'
require 'net/ftp'
require 'digest'


class Stage3
  include Singleton

  def initialize
    @local_stage3_dir = '/tmp'
    @ftp_mirror = 'de-mirror.org'
    @ftp_port = 21
    @downloaded = false
    @ftp_passive = true
    @verbose = true
    @test_only = false
    @profile_type = 'default'

  end

  def ftp_connect
    @ftp_url = "gentoo/releases/#{@arch}/current-stage3/"
    @ftp = Net::FTP.new
    puts "connecting to #{@ftp_mirror}" if verbose?
    @ftp.connect(@ftp_mirror, @ftp_port)
    @ftp.login
    @ftp.chdir @ftp_url
    @ftp.passive = @ftp_passive

    dir = @ftp.getdir
    @date = dir.split('/').last
  end

  def fetch_digest
    
    puts @ftp_mirror + @ftp_url + stage3_file
    puts stage3_dir
    @ftp.chdir stage3_dir
    @ftp.get stage3_file + '.DIGESTS', @local_stage3_dir + '/' + stage3_file + '.DIGESTS'
#    @ftp.get stage3_file + '.DIGESTS'
  end

  #TODO get right checksum from file
  def check_digest
    puts "checking digests" if verbose?
    puts digest_get = IO.readlines(stage3_digest_file_path)[1].split.first
    puts digest_count = Digest::SHA512.file(stage3_file_path).hexdigest

    unless digest_count == digest_get
      puts "Digests not match. Please remove file #{stage3_file_path} and try again"  unless digest_count == digest_get
      exit
    end
    puts "digest match" if verbose?
  end

  def downloaded?
    if File.exist?(stage3_file_path)
      puts "File #{stage3_file} downloaded" if verbose?
      return true
    else
      puts "File #{stage3_file} needs to be downloaded" if verbose?
      return false
    end
  end

  def stage3_dir
    "/#{@ftp_url}"
  end

  def stage3_digest_file_path
    "#{@local_stage3_dir}/#{stage3_file}.DIGESTS"
  end

  def stage3_file_path
    "#{@local_stage3_dir}/#{stage3_file}"
  end

  def stage3_file
    "stage3-#{@model}-#{@date}.tar.bz2"
  end

  def fetch_stage3
    @ftp.chdir stage3_dir
    @ftp.get stage3_file, @local_stage3_dir + '/' + stage3_file
    puts "getting #{stage3_file}" if verbose?
    puts "done" if verbose?
  end

  def fetch_and_unpack(destination)
    ftp_connect
    fetch_digest
    fetch_stage3 unless downloaded?
    check_digest
    unpack(destination)
  end

  def set_arch(arch)
    @arch = arch
    case @arch
      when  'x86'
        @model = 'i686'
      when 'amd64'
        @model = 'amd64'
    end

  end

  def unpack(dest_dir)
    puts  "unpacking stage3" if verbose?
    if dest_dir.match(/^\/mnt.*/)
      system("tar -xjpvf #{stage3_file_path} -C  #{dest_dir}")
    else
      puts 'chroot_dir have to begins with /mnt'
    end
  end
  
  def verbose?
    @verbose
  end
end
