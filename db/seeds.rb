[
  { title: "Learn Ruby on Rails", status: :todo },
  { title: "Learn Turbo Streams", status: :doing },
  { title: "Build Todo App",      status: :done }
].each do |attrs|
  Task.find_or_create_by!(title: attrs[:title]) { |task| task.status = attrs[:status] }
end