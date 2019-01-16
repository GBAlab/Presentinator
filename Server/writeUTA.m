function resp = writeUTA(uta12, buffer)
    buffer(1)= hex2dec('AA');
    buffer(2)= hex2dec('55');
    buffer(3) = uta12.UserData(3);
    
    checksum = 256*256-1-sum(buffer(1:22));
    buffer(23)= floor(checksum/256);
    buffer(24)= mod(checksum,256);
    fwrite(uta12,buffer)

    resp = fread(uta12,24);
    %resp(:,2) = int8(buffer)'; % second col. is the command
