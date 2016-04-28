# http://edgeguides.rubyonrails.org/action_mailer_basics.html#intercepting-emails
class SandboxEmailInterceptor
  def self.delivering_email(message)
    address == ENV["MAILINATOR_SANDBOX_ADDRESS"] ||
      "persona-duckpin-traffic-worker-outguess@mailinator.com"

    message.to = message.to.map do |email|
      ["#{email} <#{address}>"]
    end
  end
end
