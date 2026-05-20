namespace :ai do
  desc "Pull the default Ollama model"
  task setup: :environment do
    setting = Ai::Setting.instance
    model = setting.default_model
    endpoint = setting.ollama_endpoint

    puts "Pulling model '#{model}' from #{endpoint}..."
    response = Faraday.post("#{endpoint}/api/pull", { name: model }.to_json,
                            "Content-Type" => "application/json")

    if response.success?
      puts "Model '#{model}' pulled successfully."
    else
      puts "Failed to pull model: #{response.status} #{response.body}"
    end
  end
end
