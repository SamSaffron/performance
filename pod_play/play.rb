100.times do |i|
  `docker run --name parent#{i} -d --restart=always ubuntu sleep 100000`
  `docker run  --pid=container:parent#{i} --name child#{i} -d --restart=always ubuntu sleep 100000`
end
