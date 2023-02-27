ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "minitest/reporters"
require "rack/test"
Minitest::Reporters.use!
require_relative "../cms"
require "pry"
require "fileutils"

class CmsTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end
  
  def setup
    FileUtils.mkdir_p(data_path)
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
  
  def session
    last_request.env["rack.session"]
  end  

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def admin_session
    { "rack.session" => { username: "admin" } }
  end  

  def test_index
    create_document "about.md"
    create_document "changes.txt"

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  def test_view_text_file
    expected = "test data"
    create_document "history.txt", expected
    get "/history.txt"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_equal expected, last_response.body
  end

  def test_view_markdown_file
    create_document "about.md", "# Ruby is..."

    get "/about.md"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end  

  def test_file_not_found
    get "/notafile.ext"

    assert_equal 302, last_response.status
    assert_equal "notafile.ext does not exist.", session[:message]

    # get last_response["Location"] 
    # assert_equal 200, last_response.status
    # assert_includes last_response.body, "nofile does not exist"

    # get "/"
    # refute_includes last_response.body, "nofile does not exist"
  end

  def test_edit_document
    create_document "changes.txt", "test content"

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Edit content of changes.txt"
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, "test content"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_save_changes
    create_document "changes.txt"

    post "/changes.txt", {content: "new content"}, admin_session
    
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    # get last_response["Location"]
    
    # assert_includes last_response.body, "changes.txt has been updated"

    # get "/changes.txt"
    # assert_equal 200, last_response.status
    # assert_includes last_response.body, "new content"
  end

  def test_view_new_document_form
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end
  
  def test_create_new_document
    
    post "/create", {filename: "test.txt"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "test.txt was created.", session[:message]   
    # get last_response["Location"]
    # assert_includes last_response.body, "test.txt was created."

    get "/"
    assert_includes last_response.body, "test.txt"
    assert_includes last_response.body, "New Document"
  end
  
  def test_create_new_document_invalid_filename
    post "/create", {filename: ""}, admin_session
    assert_includes last_response.body, "A name is required."
  
    post "/create", {filename: "testtxt"}, admin_session
    assert_includes last_response.body, "Name must end with .txt or .md"
  
    post "/create", {filename: "testmd"}, admin_session
    assert_includes last_response.body, "Name must end with .txt or .md"
  end

  def test_delete_document
    file_name = "deleted.txt"
    create_document file_name

    get "/"
    assert_includes last_response.body, file_name

    post "/#{file_name}/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "#{file_name} has been deleted.", session[:message]
    # get last_response["Location"]
    # assert_includes last_response.body, "#{file_name} has been deleted."
    
    get "/"
    refute_includes last_response.body, %q(href="/#{file-name}")
  end

  def test_signin_form
    get "/users/signin"
    assert_equal 200, last_response.status

    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_sign_in
    post "/users/signin", username: "admin", password: "secret"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]

    get last_response["Location"]
    assert_equal 200, last_response.status
    
    # assert_includes last_response.body, "Welcome!"
    assert_equal "admin", session[:username]
    assert_includes last_response.body, "Signed in as admin"
    assert_includes last_response.body, "Sign Out"
  end


  def test_signin_bad_credentials
    post "/users/signin", username: "admin", password: "wrong_password"
    # assert_equal 302, last_response.status

    # get last_response["Location"]
    # assert_equal 200, last_response.status
    assert_equal 442, last_response.status

    assert_includes last_response.body, "Invalid credentials"
  end

  def test_signout
    post "/users/signin", username: "admin", password: "secret"
    post "/users/signout"

    assert_equal 302, last_response.status

    get last_response["Location"]
    assert_equal 200, last_response.status
    assert_includes last_response.body, "You have been signed out."

  end
end