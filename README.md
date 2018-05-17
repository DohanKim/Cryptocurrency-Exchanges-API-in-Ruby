# Cryptocurrency Exchanges API in Ruby

Supporting exchanges: [Bithumb](https://www.bithumb.com/u1/US127), [Coinone](http://doc.coinone.co.kr/)

Codes are quite self-explanatory.
You can expand this to add whatever APIs which are not implemented yet by using public_api and private_api methods.

Use the code at your OWN risk.

## Usage

```ruby
logger = Logger.new
bithumb_api = Bithumb.new(bithumb_keys['API_KEY'], bithumb_keys['SECRET_KEY'], logger)
coinone_api = Coinone.new(coinone_keys['API_KEY'], coinone_keys['SECRET_KEY'], logger)

p bithumb_api.balance('eos')
p coinone_api.balance('eos')
```
