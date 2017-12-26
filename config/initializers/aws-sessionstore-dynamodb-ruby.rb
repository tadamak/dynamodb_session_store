# CON-5598参照 aws-sessionstore-dynamodb-rubyを利用した場合にログアウトが動作しない件への対応
require 'action_dispatch/middleware/session/abstract_store'

module AWS::SessionStore::DynamoDB
  class RackMiddleware
    # session破棄可能とする
    include ActionDispatch::Session::DestroyableSession

    # debug用
    if Rails.env.development? && ENV['VERBOSE_SESSION_LOGGING']
      def set_session(env, sid, session, options)
        Rails.logger.debug "#{'='*20} SET SESSION #{sid}"
        @lock.set_session_data(env, sid, session, options)
      end

      def destroy_session(env, sid, options)
        Rails.logger.debug "#{'='*20} DESTROY SESSION #{sid}"
        @lock.delete_session(env, sid)
        generate_sid unless options[:drop]
      end

      def prepare_session(env)
        super.tap do
          Rails.logger.debug "=====>>>> COOKIE: " + Rack::Request.new(env).cookies.map { |k, v| "#{k}: #{v}" }.join(", ")
          Rails.logger.debug "=====>>>> SESSION: #{env['rack.session']}, OPTIONS: #{env['rack.session.options']}"
        end
      end

      def commit_session(env, status, headers, body)
        Rails.logger.debug "<<<<===== SESSION: #{env['rack.session']}, OPTIONS: #{env['rack.session.options']}"
        super
      end
    end
  end
end

module AWS::SessionStore::DynamoDB::Locking
  class Base
    # Updates session in database
    def set_session_data(env, sid, session, options = {})
      return sid if session.empty? # 成功扱いとする
      packed_session = pack_data(session)
      handle_error(env) do
        save_opts = update_opts(env, sid, packed_session, options)
        result = @config.dynamo_db_client.update_item(save_opts)
        sid
      end
    end

    # Attributes to update via client.
    def attr_updts(env, session, add_attrs = {})
      # CON-5666
      # 元コードは、data_unchanged?(env, session)の結果でdata部分を更新するか判定し、無駄にdataを更新しないようにしているが、判定条件が不足している。
      # 今回のように認証状態で再度ログインするケースなど、sidは変わっているが、sessionの内容自体は変わらない場合に対応できていない。
      # (新規のsidにも関わらず、dataの無いentryをdynamodbへ作成しに行ってしまう)
      # sidの変化を見るようにしても良いが、attr_updtsまでsidを引き回す必要があるのと、
      # attr_updts自体使い回されており、影響範囲が見えないためこれは避ける。
      # CONの場合、dataは大したデータ量ではないため、毎回dataを更新してたとしても問題ない。
      {
        :attribute_updates => merge_all(updated_attr, data_attr(session), add_attrs),
        :return_values => "UPDATED_NEW"
      }
    end
  end
end
