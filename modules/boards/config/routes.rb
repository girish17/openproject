Rails.application.routes.draw do
  resources :boards,
            controller: "boards/boards",
            only: %i[index new create],
            as: :work_package_boards

  scope "projects/:project_id", as: "project" do
    resources :boards,
              controller: "boards/boards",
              only: %i[index show new create destroy],
              as: :work_package_boards do
      collection do
        get "menu" => "boards/menus#show"
        get "import" => "boards/boards#import"
        post "import" => "boards/boards#import_csv"
      end
      member do
        get "export" => "boards/boards#export"
      end
      get "(/*state)" => "boards/boards#show", on: :member, as: "", constraints: { id: /\d+/ }
    end
  end
end
