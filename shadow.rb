require 'digest/sha2'

module Shadow
  def self.password(password)
    salt = rand(36**8).to_s(36)
    password.crypt("$6$" + salt)
  end
end
