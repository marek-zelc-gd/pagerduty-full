require 'json'
require 'net/http'
require 'uri'
require 'openssl'

module PagerDuty
  class Full
    attr_reader :apikey, :subdomain, :http_proxy



    @@proxy_args = []

    def initialize(apikey, subdomain, *http_proxy)
      @apikey = apikey
      @subdomain = subdomain
      @http_proxy = http_proxy

      if !@http_proxy.empty?
        proxy_url  = URI.parse(@http_proxy[0])
        @@proxy_args[0] = proxy_url.host
        @@proxy_args[1] = proxy_url.port

        if !proxy_url.user.nil?
          @@proxy_args[2] = proxy_url.user
          @@proxy_args[3] = proxy_url.password
        end
      end
    end

    def create_http(uri)
      http = Net::HTTP.new(uri.host, uri.port, *@@proxy_args)
      http.use_ssl = true
      http
    end

    def api_call(path, params)
      uri = URI.parse("https://#{@subdomain}.pagerduty.com/api/v1/#{path}")
      http = create_http(uri)

      finished = false
      whole_output = {}
      while (!finished)
        output = []
        params.each_pair do |key,val|
          if (!val.nil?)
            output << "#{URI.encode(key.to_s)}=#{URI.encode(val.to_s)}"
          end
        end
        uri.query = "#{output.join("&")}"

        res = http.get(uri.to_s, {
            'Content-type'  => 'application/json',
            'Authorization' => "Token token=#{@apikey}"
        })

        case res
          when Net::HTTPSuccess
            output = JSON.parse(res.body)
            whole_output.each_key do |key|
              if (key != "limit" && key != "offset" && key != "total" && key != "active_account_users" && key != "query" && key != "more")
                if (output.has_key?(key))
                  output[key].each do |o|
                    whole_output[key].push(o)
                  end
                end
              end
            end
            whole_output = output if (whole_output.empty?)
          else
            finished = true
            res.error!
        end

        if !output["limit"].nil? && !output["offset"].nil?
          if output["more"]
            params["offset"] = output["offset"] + output["limit"]
          else
            finished = true
          end
        else
          finished = true
        end
      end
      whole_output
    end

    def post_api_call(path, params)
      uri = URI.parse("https://#{@subdomain}.pagerduty.com/api/v1/#{path}")
      http = create_http(uri)

      res = http.post(uri.to_s, params.to_json, {
        'Content-type'  => 'application/json',
        'Authorization' => "Token token=#{@apikey}"
      })

      output = nil
      case res
        when Net::HTTPSuccess
          output = JSON.parse(res.body)
      end
      output
    end

    def put_api_call(path, params)
      uri = URI.parse("https://#{@subdomain}.pagerduty.com/api/v1/#{path}")
      http = create_http(uri)

      res = http.put(uri.to_s, params.to_json, {
        'Content-type'  => 'application/json',
        'Authorization' => "Token token=#{@apikey}"
      })

      output = nil
      case res
        when Net::HTTPSuccess
          output = JSON.parse(res.body)
      end
      output
    end

    def delete_api_call(path)
      uri = URI.parse("https://#{@subdomain}.pagerduty.com/api/v1/#{path}")
      http = create_http(uri)

      res = http.delete(uri.to_s, {
        'Content-type'  => 'application/json',
        'Authorization' => "Token token=#{@apikey}"
      })

      output = nil
      case res
        when Net::HTTPSuccess, Net::HTTPNoContent
          output = JSON.parse(res.body)
      end
      output
    end

    def integration_api_call(params)
      uri = URI.parse("https://events.pagerduty.com")
      path = "/generic/2010-04-15/create_event.json"
      http = Net::HTTP.new(uri.host, uri.port, *@@proxy_args)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE

      req = Net::HTTP::Post.new(path,initheader = {'Content-type'  => 'application/json'})
      req.body = params.to_json
      response = http.start {|http| http.request(req) }
      output = nil
      case response
        when Net::HTTPSuccess
          output = JSON.parse(response.body)
      end
      output
    end

    def Escalation()
      PagerDuty::Resource::Escalation.new(@apikey, @subdomain)
    end

    def Incident()
      PagerDuty::Resource::Incident.new(@apikey, @subdomain)
    end

    def Schedule()
      PagerDuty::Resource::Schedule.new(@apikey, @subdomain)
    end

    def Service()
      PagerDuty::Resource::Service.new(@apikey, @subdomain)
    end

    def Users()
      PagerDuty::Resource::Users.new(@apikey, @subdomain)
    end
  end
end
