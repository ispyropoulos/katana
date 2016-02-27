# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += %w( dashboard.js dashboard.css front.css front.js codemirror.js formatting.js yaml.js shell.js custom.codemirror.js github.svg favicon-16x16.png profile-photos/* service-logos/*)
Rails.application.config.assets.precompile << /\.(?:svg|eot|woff|ttf)\z/
