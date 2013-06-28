module Celluloid
  class Dashboard
    class Application < Sinatra::Base
      configure do
        helpers  Sinatra::ContentFor
        register Sinatra::Flash
        
        enable :sessions
        enable :method_override
        set    :connections, Set.new
      end

      configure :development do
        set :slim, pretty: true
      end

      class << self
        def notify(notification)
          data = {
            datetime: notification[:time].iso8601,
            time:     notification[:time].strftime('%F %T'),
            topic:    notification[:topic],
            args:     notification[:args].inspect
          }.to_json

          message = "event:notification\ndata:#{data}\n\n"
          connections.each { |c| c << message }
        end

        def clear_connections
          settings.connections.clear
        end
      end

      get '/' do
        slim :actors
      end

      get '/actors' do
        redirect '/'
      end

      get '/actors/:mailbox_address' do
        if @actor = get_actor(params[:mailbox_address])
          if @actor.alive?
            @actors = []

            (actors - [@actor]).each do |actor|
              if linked = @actor.linked_to?(actor)
                @actors.unshift({actor: actor, linked: linked})
              else
                @actors.push({actor: actor, linked: linked})
              end
            end

            slim :actor
          else
            404
          end
        else
          404
        end
      end

      delete '/actors/:mailbox_address' do
        if actor = get_actor(params[:mailbox_address])
          name = Rack::Utils.escape_html(actor_name(actor))
          actor.async.terminate
          flash[:info] = "Trying to terminate Actor <b>#{name}</b>."
        else
          flash[:error] = 'Actor not found or dead.'
        end

        redirect(back || '/')
      end

      post '/actors/:mailbox_address/links/:link_mailbox_address' do
        if actor = get_actor(params[:mailbox_address])
          if link = get_actor(params[:link_mailbox_address])
            if actor == link
              flash[:error] = 'Actor and Link are equal.'
              redirect "/actors/#{params[:mailbox_address]}"
            else
              if actor.linked_to?(link)
                flash[:error] = 'Actors already linked.'
                redirect "/actors/#{params[:mailbox_address]}"
              else
                actor.async.link(link)
                flash[:info] = 'Trying to link Actors.'
                redirect "/actors/#{params[:mailbox_address]}"
              end
            end
          else
            flash[:error] = 'Link Actor not found or dead.'
            redirect "/actors/#{params[:mailbox_address]}"
          end
        else
          flash[:error] = 'Actor not found or dead.'
          redirect '/'
        end
      end

      delete '/actors/:mailbox_address/links/:linked_mailbox_address' do
        if actor = get_actor(params[:mailbox_address])
          if link = get_actor(params[:linked_mailbox_address])
            if actor.linked_to?(link)
              actor.async.unlink(link)
              flash[:info] = 'Trying to unlink Actors.'
              redirect "/actors/#{params[:mailbox_address]}"
            else
              flash[:error] = 'Actors are not linked.'
              redirect "/actors/#{params[:mailbox_address]}"
            end
          else
            flash[:error] = 'Linked Actor not found or dead.'
            redirect "/actors/#{params[:mailbox_address]}"
          end
        else
          flash[:error] = 'Actor not found or dead.'
          redirect '/'
        end
      end

      # get '/notifications' do
      #   slim :notifications
      # end

      # get '/notifications/stream', provides: 'text/event-stream' do
      #   stream(:keep_open) do |out|
      #     settings.connections << out
      #     out.callback { settings.connections.delete(out) }
      #     out.errback { settings.connections.delete(out) }
      #   end
      # end

      # # TODO: Route fix: ohne create
      # post '/notifications/create' do
      #   topic, message = params[:topic], params[:message]
      #   if topic && !topic.empty? && message && !message.empty?
      #     Notifier.instance.async.publish(topic, message)
      #     flash[:success] = 'Notification sent.'
      #   else
      #     flash[:error] = 'Topic and/or Message missing.'
      #   end

      #   redirect '/notifications'
      # end

      helpers do
        def terminate_actor_button(mailbox_address)
          slim :_terminate_actor_button, locals: {mailbox_address: mailbox_address}
        end

        def terminate_task_button(object_id)
          slim :_terminate_task_button, locals: {object_id: object_id}
        end

        def unlink_actor_button(mailbox_address, linked_mailbox_address)
          locals = {
            mailbox_address: mailbox_address,
            linked_mailbox_address: linked_mailbox_address
          }
          slim :_unlink_actor_button, locals: locals
        end

        def link_actor_button(mailbox_address, linked_mailbox_address)
          locals = {
            mailbox_address: mailbox_address,
            linked_mailbox_address: linked_mailbox_address
          }
          slim :_link_actor_button, locals: locals
        end

        def actors
          # Thread.list.select do |t|
          #   t.celluloid? && t.role == :actor && t.actor
          # end.map(&:actor)

          @_actors ||= Celluloid::Actor.all
        end

        def get_actor(mailbox_address)
          # object = begin
          #   object_id = Integer(object_id)
          #   ObjectSpace._id2ref(object_id)
          # rescue StandardError
          #   return nil
          # end

          # actor?(object) ? object : nil

          actors.select do |actor|
            actor.mailbox.address == mailbox_address
          end.first
        end

        # def actor?(object)
        #   object_singleton = class << object; self; end
        #   object_singleton.ancestors.include?(ActorProxy)
        # end

        def actor_name(actor)
          actor.name || actor.to_s
        end

        def active_helper(path)
          if request.path.split('/')[1..-1] == path
            'active'
          end
        end

        def create_links_object
          links = Hash.new { |hash, key| hash[key] = [] }
          actors.each do |actor|
            actor.links.each do |linked_actor|
              links[actor.mailbox.address] << linked_actor.mailbox.address
            end
          end
          links.to_json
        end
      end

      # Sinatra won't tell if any errors occur while trying to
      # start up a server. Sucks big times. Changed that behaviour
      # for this subclass. Also, do not setup signal trapping,
      # the Dashboard will handle stopping the server at_exit.
      #
      # Source: https://github.com/sinatra/sinatra/blob/96c755ed279d385f4a84d100a8c6a1ae6645dd7d/lib/sinatra/base.rb#L1403-L1420
      def self.run!(options = {})
        set options
        handler         = detect_rack_handler
        handler_name    = handler.name.gsub(/.*::/, '')
        server_settings = settings.respond_to?(:server_settings) ? settings.server_settings : {}
        handler.run self, server_settings.merge(:Port => port, :Host => bind) do |server|
          unless handler_name =~ /cgi/i
            $stderr.puts "== Sinatra/#{Sinatra::VERSION} has taken the stage " +
            "on #{port} for #{environment} with backup from #{handler_name}"
          end
          # [:INT, :TERM].each { |sig| trap(sig) { quit!(server, handler_name) } }
          server.threaded = settings.threaded if server.respond_to? :threaded=
          set :running, true
          yield server if block_given?
        end
      # rescue Errno::EADDRINUSE
      #   $stderr.puts "== Someone is already performing on port #{port}!"
      end
    end
  end
end
