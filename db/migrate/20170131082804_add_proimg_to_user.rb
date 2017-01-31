class AddProimgToUser < ActiveRecord::Migration[5.0]
  def change
    add_column :users, :proimg, :string
  end
end
