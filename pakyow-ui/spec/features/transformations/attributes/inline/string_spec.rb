RSpec.describe "modifying string attributes" do
  include_context "testable app"
  include_context "websocket intercept"

  context "setting" do
    let :app_definition do
      Proc.new do
        instance_exec(&$ui_app_boilerplate)

        resources :posts, "/posts" do
          disable_protection :csrf

          list do
            expose :posts, data.posts
            render "/attributes/posts"
          end

          create do
            data.posts.create; halt
          end
        end

        source :posts do
          primary_id
        end

        presenter "/attributes/posts" do
          if posts.count > 0
            find(:post).attrs[:title] = "foo"

            # if we don't set this, the view won't quite match
            find(:post).attrs[:style] = {}
          end
        end
      end
    end

    it "transforms" do |x|
      transformations = save_ui_case(x, path: "/posts") do
        call("/posts", method: :post)
      end

      expect(transformations[0][:calls].to_json).to eq(
        '[["find",[["post"]],[],[["attrs",[],[],[["[]=",["title","foo"],[],[]]]]]],["find",[["post"]],[],[["attrs",[],[],[["[]=",["style",{}],[],[]]]]]]]'
      )
    end
  end
end
