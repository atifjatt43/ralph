require "ralph"

class CreateComments_20260107000003 < Ralph::Migrations::Migration
  migration_version 20260107000003

  def up : Nil
    create_table "comments" do |t|
      t.primary_key
      t.text "body", null: false
      t.references "user"
      t.references "post"
      t.column "created_at", :timestamp
    end

    add_index "comments", "user_id"
    add_index "comments", "post_id"
  end

  def down : Nil
    drop_table "comments"
  end
end

Ralph::Migrations::Migrator.register(CreateComments_20260107000003)
