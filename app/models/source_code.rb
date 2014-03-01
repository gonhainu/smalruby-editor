# -*- coding: utf-8 -*-

require 'tempfile'
require 'open3'
require 'digest/sha2'
require 'bundler'
silence_warnings do
  require_relative 'concerns/ruby_to_block'
end

# ソースコードを表現するモデル
class SourceCode < ActiveRecord::Base
  include RubyToBlock

  validates :filename, presence: true
  validate :validate_filename
  validates :data, presence: true, allow_blank: true

  # シンタックスをチェックする
  def check_syntax
    _, stderr_str, status = *open3_capture3_ruby_c
    return [] if status.success?

    stderr_str.lines.each.with_object([]) { |line, res|
      if (md = /^.*:(\d+): (.*)$/.match(line))
        res << { row: md[1].to_i, column: 0, message: md[2] }
      elsif (md = /( +)\^$/.match(line))
        res[-1][:column] = md[1].length
      end
    }
  end

  # プログラムを実行する
  def run(path)
    _, stderr_str, status = *open3_capture3_run_program(path)
    return [] if status.success?

    parse_ruby_error_messages(stderr_str)
  end

  # ハッシュ値を計算する
  def digest
    Digest::SHA256.hexdigest(data)
  end

  private

  def validate_filename
    if File.basename(filename) != filename
      errors.add(:filename, 'includes directory separator(s)')
    end
  end

  def ruby_cmd
    path = Pathname('rsdl').expand_path(RbConfig::CONFIG['bindir'])
    if path.exist?
      path
    else
      Pathname(RbConfig::CONFIG['RUBY_INSTALL_NAME'])
        .expand_path(RbConfig::CONFIG['bindir'])
    end
  end

  def open3_capture3_ruby_c
    tempfile = Tempfile.new('smalruby-editor')
    tempfile.write(data)
    path = tempfile.path
    tempfile.close

    Bundler.with_clean_env do
      Open3.capture3("#{ruby_cmd} -c #{path}")
    end
  end

  def open3_capture3_run_program(path)
    Bundler.with_clean_env do
      Open3.capture3("#{ruby_cmd} #{path}")
    end
  end

  def parse_ruby_error_messages(stderr_str)
    stderr_str.lines.each.with_object([]) { |line, res|
      if (md = /^\tfrom .*:(\d+):(in .*)$/.match(line))
        res << { row: md[1].to_i, column: 0, message: md[2] }
      elsif (md = /^.*:(\d+):(in .*)$/.match(line))
        res << { row: md[1].to_i, column: 0, message: md[2] }
      elsif (md = /( +)\^$/.match(line))
        res[-1][:column] = md[1].length
      else
        row = res[-1] ? res[-1][:row] : 0
        res << { row: row, column: 0, message: line.chomp }
      end
    }
  end
end
