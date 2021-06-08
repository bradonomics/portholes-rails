Rails.application.routes.draw do

  # root "folders#show"
  root to: redirect('/folder/unread')

  devise_for :user,
  controllers: {
    registrations: 'users/registrations'
  }
  # path: "",
  # path_names: {
  #   sign_in: "login",
  #   sign_out: "logout",
  #   sign_up: "register"
  # }

  # get '/user', to: redirect('/folder/unread')

  get "folder/:permalink" => "folders#show", as: "folder_permalink"
  get "folder/:permalink/download" => "folders#download", as: "download_folder"
  patch "folder/:id/archive-all" => "folders#archive_all", as: "archive_all"
  resources :folders, path: "/folder" do
    member do
      patch :sort
    end
  end

  resources :articles, path: "/article" do
    member do
      patch :archive
      patch :unarchive
    end
  end
  # resources :articles, only: [:index]

  namespace :hello, defaults: { format: 'js' } do
    # resources :articles
    get ":hello_token" => "articles#index"
    post ":hello_token" => "articles#create"
  end

end
