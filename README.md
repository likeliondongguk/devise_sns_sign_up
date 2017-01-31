# Devise와 Ommiauth를 이용하여 SNS 아이디로 로그인

Devise gem과 omniauth gem을 활용하여 facebook, google, kakao 아이디로 로그인할 수 있도록 해주는 기능입니다. + 프로필 이미지를 사용하는 기능입니다.

## Getting Started

다음의 gem을 설치합니다.

### Gemfile

```
gem 'devise'

gem 'omniauth-facebook'
gem 'omniauth-naver'
gem 'omniauth-google-oauth2'
gem 'omniauth-kakao'
```
```
bundle install
```

### 필요한 MVC 설정

```
rails g controller home index
rails generate devise:install
rails generate devise user
rails generate devise:views user
rails generate devise:controllers user
rails g migration add_name_to_users name:string
rails g migration add_proimg_to_users proimg:string
rails g model identity user:references provider:string uid:string
rake db:migrate
```

### app/views/home/index.html.erb

```
<% if user_signed_in? %>
    <%= User.where(email: current_user.email).inspect %>
    <p><%= image_tag "#{current_user.proimg}" %></p>
    <%= link_to('Logout', destroy_user_session_path, :method => :delete) %>
<% else %>
    <%= User.all.inspect %>
    <%User.all.each do |a|%>
      <p><%= image_tag "#{a.proimg}" %></p>
    <%end%>
    <%= link_to('Login', new_user_session_path) %>
<% end %>
```


### config/initializers/devise.rb

```
config.omniauth :facebook, "key", "secret"
config.omniauth :naver, "key", "secret"
config.omniauth :google_oauth2, "key", "secret"
config.omniauth :kakao, "key", :redirect_path => "/users/auth/kakao/callback"  
```

### config/routes

```
Rails.application.routes.draw do
  root 'home#index'
  devise_for :users, :controllers => { omniauth_callbacks: 'user/omniauth_callbacks' }
  get 'home/index'

  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
```

### app/models/identity.rb

```
class Identity < ActiveRecord::Base
  belongs_to :user
  validates_presence_of :uid, :provider
  validates_uniqueness_of :uid, :scope => :provider

  def self.find_for_oauth(auth)
    find_or_create_by(uid: auth.uid, provider: auth.provider)
  end
end
```

### app/models/user.rb

```
class User < ActiveRecord::Base

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
    devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable

  TEMP_EMAIL_PREFIX = 'jongwon@me'
  TEMP_EMAIL_REGEX = /\Achange@me/

  def self.find_for_oauth(auth, signed_in_resource = nil)

    # Get the identity and user if they exist
    identity = Identity.find_for_oauth(auth)

    # If a signed_in_resource is provided it always overrides the existing user
    # to prevent the identity being locked with accidentally created accounts.
    # Note that this may leave zombie accounts (with no associated identity) which
    # can be cleaned up at a later date.
    user = signed_in_resource ? signed_in_resource : identity.user

    # Create the user if needed
    if user.nil?
      # Get the existing user by email if the provider gives us a verified email.
      # If no verified email was provided we assign a temporary email and ask the
      # user to verify it on the next step via UsersController.finish_signup

      email_is_verified = auth.info.email || (auth.info.verified || auth.info.verified_email)
      email = auth.info.email if email_is_verified
      user = User.where(:email => email).first if email
      #프로필 사진 추가부분
      proimg = auth.info.image
      proimg ? proimg.sub!("https","http") : nil
      # Create the user if it's a new registration
      if user.nil?
        user = User.new(
          name: auth.info.name || auth.extra.nickname ||  auth.uid,
          email: email ? email : "#{TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com",
          proimg: proimg ? proimg : "null",
          password: Devise.friendly_token[0,20]
        )
        user.save!

      end
    end
    # Associate the identity with the user if needed
    if identity.user != user
      identity.user = user
      identity.save!

    end

    user

  end

  def email_required?
    false
  end

  def email_changed?
    false
  end
end

```

### app/controllers/user/omniauth_callbacks_controller.rb

```
class User::OmniauthCallbacksController < Devise::OmniauthCallbacksController

  def self.provides_callback_for(provider)
    class_eval %Q{
      def #{provider}
        @user = User.find_for_oauth(env["omniauth.auth"], current_user)

        if @user.persisted?
          sign_in_and_redirect @user, event: :authentication
          set_flash_message(:notice, :success, kind: "#{provider}".capitalize) if is_navigational_format?
        else
          session["devise.#{provider}_data"] = env["omniauth.auth"]
          redirect_to new_user_registration_url
        end
      end
    }
  end

  [:instagram, :kakao, :naver, :facebook, :google_oauth2, :line].each do |provider|
    provides_callback_for provider
  end

  def after_sign_in_path_for(resource)
      root_path
  end
end
```
