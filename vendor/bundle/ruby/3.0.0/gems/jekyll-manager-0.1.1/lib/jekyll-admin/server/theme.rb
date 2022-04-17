module JekyllAdmin
  class Server < Sinatra::Base
    namespace "/theme" do
      get do
        ensure_theme
        json({
          :name        => theme.name,
          :version     => theme.version,
          :authors     => theme.authors.join(", "),
          :license     => theme.license,
          :summary     => theme.summary,
          :description => theme.description,
          :path        => at_root,
          :directories => entries.map(&:to_api),
        })
      end

      get "/*?/?:path.:ext" do
        ensure_requested_file
        json({
          :name            => filename,
          :path            => file_path,
          :relative_path   => relative_path_of(file_path),
          :raw_content     => raw_content,
          :exist_at_source => exist_at_source?,
          :http_url        => http_url(file_path),
          :api_url         => url,
        })
      end

      get "/?*" do
        ensure_directory_in_theme
        json({
          :name    => splats.first.split("/").last || theme.name,
          :path    => at_root(splats.first),
          :entries => entries.map(&:to_api).concat(subdir_entries),
        })
      end

      put "/*?/?:path.:ext" do
        write_file write_path, raw_content
        json({
          :name            => filename,
          :path            => write_path,
          :relative_path   => relative_path_of(file_path),
          :raw_content     => raw_content,
          :exist_at_source => true,
          :http_url        => http_url(file_path),
          :api_url         => url,
        })
      end

      private

      def ensure_theme
        render_404 unless site.theme
      end

      def ensure_directory_in_theme
        ensure_theme
        ensure_directory
      end

      def ensure_requested_file
        render_404 unless File.exist?(file_path)
      end

      def at_root(dir = "")
        site.in_theme_dir(dir)
      end

      def theme
        site.theme.send(:gemspec)
      end

      def directory_path
        site.in_theme_dir(splats.first)
      end

      def entries
        args = {
          :base         => site.theme.root,
          :content_type => "theme",
          :splat        => splats.first,
        }
        Directory.new(directory_path, args).directories
      end

      def subdir_entries
        Dir["#{directory_path}/*"].reject { |e| File.directory?(e) }.map! do |e|
          {
            :name     => relative_path_of(e).sub("#{splats.first}/", ""),
            :extname  => File.extname(e),
            :http_url => http_url(e),
            :api_url  => api_url(e),
          }
        end
      end

      def splats
        params["splat"] || ["/"]
      end

      def file_path
        File.join(directory_path, filename)
      end

      def relative_path_of(entry)
        entry.sub(at_root, "")
      end

      def api_url(entry)
        File.join(base_url, "_api", "theme", relative_path_of(entry))
      end

      def http_url(entry)
        if splats.first.include?("assets") && !Jekyll::Utils.has_yaml_header?(entry)
          File.join(base_url, relative_path_of(entry))
        end
      end

      def write_path
        File.join(site.source, relative_path_of(file_path))
      end

      def exist_at_source?
        File.exist? write_path
      end

      def raw_content
        File.read(file_path, Jekyll::Utils.merged_file_read_opts(site, {}))
      end
    end
  end
end
