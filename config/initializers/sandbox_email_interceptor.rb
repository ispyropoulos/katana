# http://edgeguides.rubyonrails.org/action_mailer_basics.html#intercepting-emails
if Rails.env.development?
  ActionMailer::Base.register_interceptor(SandboxEmailInterceptor)
end
