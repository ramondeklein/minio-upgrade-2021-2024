#!/bin/bash
for i in ?[1-4]d[12]
do 
	(cd $i/.minio.sys; tar czf ../../miniosys-$i.tgz .)
done
