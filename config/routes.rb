class ActionDispatch::Routing::Mapper
  def draw(scope, routes_name)
    instance_eval(
      File.read(Rails.root.join("config/routes/#{scope}/#{routes_name}.rb"))
    )
  end
end

PrintHubApp::Application.routes.draw do

  constraints(CustomerSubdomain) do
    draw :customer, :catalog
    draw :customer, :feedback
    draw :customer, :customer_session
    draw :customer, :customer
    draw :customer, :password_reset
    draw :customer, :order
    draw :customer, :files
  end

  constraints(UserSubdomain) do
    draw :user, :stat
    draw :user, :bonus
    draw :user, :article
    draw :user, :payment
    draw :user, :shift
    draw :user, :customer
    draw :user, :order
    draw :user, :print
    draw :user, :document
    draw :user, :tag
    draw :user, :user_session
    draw :user, :user
    draw :user, :files
    draw :user, :print_job_types
  end

  root to: 'subdomains#redirection' # Momentary solution for double root-to
end
