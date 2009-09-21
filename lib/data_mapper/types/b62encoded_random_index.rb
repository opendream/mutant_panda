require 'rubygems'
require 'uuid'

module DataMapper
  module Types
    class B62EncodedRandomIndex < DataMapper::Type
      primitive String
      unique true
      size 20
      default lambda { 
#         u = UUID.respond_to?(:generate) ? UUID.generate : UUID.new
#         n = eval "0x#{u.gsub('-', '')}"  # convert hex to int
        digits = %w{0 1 2 3 4 5 6 7 8 9
                    a b c d e f g h i j k l m n o p q r s t u v w x y z 
                    A B C D E F G H I J K L M N O P Q R S T U V W X Y Z}
        result = ""
        20.times { result << digits[(rand*62).floor] }
        result
#         result = ""
#         while n > 0  # encode the base10 in to base62 using the 62 digits
#           rest, units = n.divmod(62)
#           result = digits[units] + result
#           n = rest
#         end
#         result
      }
    end # class UUID
  end # module Types
end # module DataMapper
