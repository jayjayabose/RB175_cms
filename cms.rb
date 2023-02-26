require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
# require "fileutils"

configure do
  enable :sessions
  # set :session_secret, 'super secret'
end

# cms.rb
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

# root = File.expand_path("..", __FILE__)
def load_file_content(path)
  content = File.read(path)
  
  case File.extname(path)
  when ".txt"
    content
  when ".md"
    render_markdown(content)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)  
end

def get_error_message(file_name)
  return "A name is required." if file_name.empty?
  # return "Name must end with .txt or .md" unless file_name.match?(/(\.txt\z)|(\.md\z)/)
  return "Name must end with .txt or .md" unless ['.md', '.txt'].include? File.extname(file_name)
end

# Display signin form
get "/users/signin" do
  erb :signin
end

# Handle user signin 
post "/users/signin" do
  if params[:username] == "admin" && params[:password] == "secret"
    session[:username] = params[:username]
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials"
    status 442
    erb :signin
  end
end

#Handle user signout
post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

# Display new document form
get "/new" do
  erb :new
end

# Create new document 
post "/create" do
  file_name = params[:filename].to_s

  error_message = get_error_message(file_name)
  if error_message
    session[:message] = error_message
    status 442
    erb :new
  else
    file_path = File.join(data_path, file_name)
    File.write(file_path, "")
    session[:message] = "#{file_name} was created."
    redirect "/"
  end

end

post "/:filename/delete" do
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)
  File.delete(file_path)
  session[:message] = "#{file_name} has been deleted."
  redirect "/"
end

# Display list of files
get "/" do
  # if session[:username].nil?
  #   redirect "/users/signin"
  # else
    pattern = File.join(data_path, "*")
    @files = Dir.glob(pattern).map do |full_path_name|
      File.basename(full_path_name)
    end
    erb :index
  # end
end

#Display file contents
get "/:filename" do
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)

  if File.file? file_path
    headers["Content-Type"] = "text/html;charset=utf-8"
    load_file_content(file_path)
  else
    session[:message] = "#{file_name} does not exist."
    redirect "/"
  end
end

# Dipsplay file edit page
get "/:filename/edit" do
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)

  @content = File.read(file_path)
  erb :edit
end

post "/:filename" do
  content = params[:content]
  file_name = params[:filename]
  file_path = File.join(data_path, file_name)
  File.open(file_path, "w") { |f| f.write content }

  session[:message] = "#{file_name} has been updated."
  redirect "/"
end

