-- https://github.com/morgan3d/misc/tree/master/p8sort
function sort(data)
  for num_sorted=1,#data-1 do 
   local new_val=data[num_sorted+1]
   local new_val_key=new_val.key
   local i=num_sorted+1
 
   while i>1 and new_val_key>data[i-1].key do
    data[i]=data[i-1]   
    i-=1
   end
   data[i]=new_val
  end
 end