require "active_support/core_ext/enumerable"
require "peatio"

module Peatio
  module Nem2
    class Error < StandardError; end
    require "peatio/nem2/version"
    require "peatio/nem2/client"
    require "peatio/nem2/blockchain"
    require "peatio/nem2/wallet"
    require "peatio/nem2/hooks"
    require "peatio/nem2/client"
  end
end
