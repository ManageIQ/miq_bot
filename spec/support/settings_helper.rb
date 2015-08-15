def stub_settings(*args)
  value = args.pop
  allow(Settings).to receive_message_chain(*args).and_return(value)
end
