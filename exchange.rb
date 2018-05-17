require 'uri'
require 'net/http'
require 'net/https'
require 'json'
require 'openssl'
require 'base64'
require 'date'

class Exchange
  # manipulating the metaclass
  class << self 
    attr_accessor :fee
  end

  @fee = 0

  def initialize(api_key, secret_key, logger)
    @api_key = api_key
    @secret_key = secret_key
    @logger = logger
  end

  def check_and_get_response_body(res, &error_check) 
    if res.code != '200'
      return nil
    end

    body = JSON.parse(res.body)
    if error_check.call(body)
      return nil
    else 
      return body
    end
  end

  def buying_quantity_including_exchange_fee(quantity)
    return quantity * (1 + self.class.fee)
  end
end

class Bithumb < Exchange
  SERVER = "https://api.bithumb.com"

  @fee = 0.0015

  def check_and_get_response_body(res)
    return super(res) do |body|
      body['status'] != '0000'
    end
  end

  def private_api(endpoint, params = {})
    uri = URI(SERVER + endpoint)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    nonce = DateTime.now.strftime('%Q')

    str_data = URI.encode_www_form({endpoint: endpoint}.merge(params))
    data = endpoint + 0.chr + str_data + 0.chr + nonce

    digest = OpenSSL::Digest.new('sha512')
    h = OpenSSL::HMAC.hexdigest(digest, @secret_key, data)
    api_sign = Base64.strict_encode64(h)

    header = {'Api-Key': @api_key, 'Api-Sign': api_sign, 'Api-Nonce': nonce}
    req = Net::HTTP::Post.new(uri.path, header)
    req.body = str_data
    res = https.request(req)

    return res
  end

  def public_api(endpoint, params = {})
    uri = URI(SERVER + endpoint)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    uri.query = URI.encode_www_form(params)

    res = Net::HTTP.get_response(uri)

    return res
  end

  def account_info
    res = private_api("/info/account")
    body = check_and_get_response_body(res)

    if body.nil? 
      return {error: true}
    else
      ret = {}
      ret[:error] = false
      ret[:fee] = body['data']['trade_fee']
      return ret
    end
  end

  def balance(coin_code)
    res = private_api("/info/balance", {currency: coin_code})
    body = check_and_get_response_body(res)

    if body.nil? 
      return {error: true}
    else
      ret = {}
      ret[:available_krw] = body['data']['available_krw']
      ret[('total_'+ coin_code).to_sym] = body['data']['total_' + coin_code]
      ret[('available_' + coin_code).to_sym] = body['data']['available_' + coin_code]
      return ret
    end
  end

  def orderbook(coin_code)
    res = public_api("/public/orderbook/#{coin_code}")
    body = check_and_get_response_body(res)
    ret = {}

    if body.nil? 
      return {error: true}
    else
      ret = {}
      ret[:error] = false
      ret[:timestamp] = body['data']['timestamp']
      ret[:highest_bid] = body['data']['bids'][0]['price'].to_i
      ret[:lowest_ask] = body['data']['asks'][0]['price'].to_i
      return ret
    end
  end

  def buy(coin_code, price, quantity)
    res = private_api("/trade/place", {order_currency: coin_code, units: quantity, price: price, type: 'bid'})
    body = check_and_get_response_body(res)

    if body.nil? 
      logger.error(JSON.parse(res.body))
      return {error: true}
    else
      ret = {}
      ret[:error] = false
      return ret
    end
  end

  def sell(coin_code, price, quantity)
    res = private_api("/trade/place", {order_currency: coin_code, units: quantity, price: price, type: 'ask'})
    body = check_and_get_response_body(res)

    if body.nil? 
      logger.error(JSON.parse(res.body))
      return {error: true}
    else
      ret = {}
      ret[:error] = false
      return ret
    end
  end
end

class Coinone < Exchange
  SERVER = "https://api.coinone.co.kr"

  @fee = 0.001  

  def check_and_get_response_body(res)
    return super(res) do |body|
      body['result'] != 'success'
    end
  end

  def private_api(endpoint, params = {})
    uri = URI(SERVER + endpoint)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    nonce = DateTime.now.strftime('%Q')

    json_payload = {access_token: @api_key, nonce: nonce}.merge(params).to_json
    encoded_payload = Base64.strict_encode64(json_payload)

    digest = OpenSSL::Digest.new('sha512')
    sign = OpenSSL::HMAC.hexdigest(digest, @secret_key.upcase, encoded_payload)

    header = {'Content-Type': 'application/json', 'X-COINONE-PAYLOAD': encoded_payload, 'X-COINONE-SIGNATURE': sign}
    req = Net::HTTP::Post.new(uri.path, header)
    req.body = encoded_payload
    res = https.request(req)

    return res
  end

  def public_api(endpoint, params = {})
    uri = URI(SERVER + endpoint)
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    uri.query = URI.encode_www_form(params)

    res = Net::HTTP.get_response(uri)

    return res
  end

  def account_info
    res = private_api("/v2/account/user_info")
    body = check_and_get_response_body(res)

    if body.nil? 
      return {error: true}
    else
      ret = {}
      ret[:error] = false
      ret[:fee] = body['userInfo']['feeRate'][coin_code]['taker']
      return ret
    end
  end

  def balance(coin_code)
    res = private_api("/v2/account/balance")
    body = check_and_get_response_body(res)

    if body.nil? 
      return {error: true}
    else
      ret = {}
      ret[:error] = false
      ret[:total_krw] = body['krw']['balance']
      ret[:available_krw] = body['krw']['avail']
      ret[('total_'+ coin_code).to_sym] = body[coin_code]['balance']
      ret[('available_' + coin_code).to_sym] = body[coin_code]['avail']
      return ret
    end
  end

  def orderbook(coin_code)
    res = public_api("/orderbook", {currency: coin_code})
    body = check_and_get_response_body(res)

    if body.nil?
      return {error: true}
    else
      ret = {}
      ret[:error] = false
      ret[:timestamp] = body['timestamp'] + '000'
      ret[:highest_bid] = body['bid'][0]['price'].to_i
      ret[:lowest_ask] = body['ask'][0]['price'].to_i
      return ret
    end
  end

  def buy(coin_code, price, quantity)
    res = private_api("/v2/order/limit_buy", {currency: coin_code, qty: quantity, price: price})
    body = check_and_get_response_body(res)

    if body.nil? 
      log(JSON.parse(res.body))
      return {error: true}
    else
      ret = {}
      ret[:error] = false
      return ret
    end
  end

  def sell(coin_code, price, quantity)
    res = private_api("/v2/order/limit_sell", {currency: coin_code, qty: quantity, price: price})
    body = check_and_get_response_body(res)

    if body.nil? 
      log(JSON.parse(res.body))
      return {error: true}
    else
      ret = {}
      ret[:error] = false
      return ret
    end
  end
end
