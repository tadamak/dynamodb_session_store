# Be sure to restart your server when you modify this file.

AWS.config({ region: "ap-northeast-1" })
Rails.application.config.session_store :dynamodb_store
