require 'kwalify'

namespace :check do
  namespace :yaml do
    desc '"build_spec/*.yaml"のフォーマットが正しいかをチェックする'
    task :build_spec do
      exit validate "build_spec/kwalify/scheme.yaml", "build_spec/*.yaml"
    end

    private
    def validate scheme_path, yaml_path
      schema = Kwalify::Yaml.load_file(scheme_path)
      validator = Kwalify::Validator.new(schema)

      has_error = false
      Dir[yaml_path].each do |path|
        document = Kwalify::Yaml.load_file(path)

        error = validator.validate(document)
        error.each do
          |e| puts "[#{e.path}] #{e.message}"
        end
        has_error = !error.empty? unless has_error
      end
      !has_error
    end
  end
end
