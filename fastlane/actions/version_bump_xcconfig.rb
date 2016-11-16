require 'semantic'

module Fastlane
  module Actions
    module SharedValues
      XCCONFIG_VERSION_NUMBER = :XCCONFIG_VERSION_NUMBER
    end

    class VersionBumpXcconfigAction < Action
      def self.run(params)
        xcconfig_path = params[:path]

        UI.user_error!("Could not find xcconfig file at path #{xcconfig_path}") unless File.exist? xcconfig_path

        regex = /(CURRENT_PROJECT_VERSION)\s+=\s+(.*)/
        xcconfig_content = File.read(xcconfig_path)

        if params[:version_number]
          new_semver = Semantic::Version.new params[:version_number]
          new_version.build = new_version.pre = nil
        else
          version_match = xcconfig_content.match(regex)
          UI.user_error!("Could not find version in xcconfig content '#{@xcconfig_content}'") if version_match.nil?
          new_semver = Semantic::Version.new version_match[2]
          new_semver = new_semver.increment!(params[:bump_type]) unless params[:bump_type].nil?
        end

        File.write(xcconfig_path, xcconfig_content.gsub(regex, "\\1 = #{new_semver}"))

        new_semver.pre = params[:version_pre]
        Actions.lane_context[SharedValues::XCCONFIG_VERSION_NUMBER] = new_semver.to_s
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Increment or set the version in an xcconfig file"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :path,
                                       env_name: "FL_VERSION_BUMP_XCCONFIG_PATH",
                                       description: "You must specify the path to the podspec file to update",
                                       default_value: "",
                                       verify_block: proc do |value|
                                         UI.user_error!("Please pass a path to the `version_bump_xcconfig` action") if value.length == 0
                                       end),
          FastlaneCore::ConfigItem.new(key: :bump_type,
                                       type: Symbol,
                                       env_name: "FL_VERSION_BUMP_XCCONFIG_BUMP_TYPE",
                                       description: "The type of this version bump. Available: major, minor, patch",
                                       verify_block: proc do |value|
                                         UI.user_error!("Available values are ':major', ':minor', ':patch'") unless [:major, :minor, :patch].include? value
                                       end,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :version_number,
                                       env_name: "FL_VERSION_BUMP_XCCONFIG_VERSION_NUMBER",
                                       description: "Change to a specific version. This will replace the bump type value",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :version_pre,
                                       env_name: "FL_VERSION_BUMP_XCCONFIG_VERSION_PRE",
                                       description: "Add prerelease label to bumped version under semver",
                                       optional: true)
        ]
      end

      def self.output
        [
          ['XCCONFIG_VERSION_NUMBER', 'The new xcconfig version number']
        ]
      end

      def self.authors
        ["zwaldowski"]
      end

      def self.example_code
        [
          'version = version_bump_xcconfig(path: "Configurations/Base.xcconfig", bump_type: "patch")',
          'version = version_bump_xcconfig(path: "Configurations/Base.xcconfig", version_number: "1.4")',
          'version = version_bump_xcconfig(path: "Configurations/Base.xcconfig", version_pre: "beta.3")'
        ]
      end

      def self.category
        :misc
      end
    end
  end
end
