#set output dir
$destDir='D:\Users\STADUD\Documents\GitHub\deploy'
$env = 'TEST'

$libDir = 'D:\Users\STADUD\Downloads\sharepointclientcomponents_16-6518-1200_x64-en-us'


$appCatalogUrl ='http://<MySite>/sites/appcatalog/'

$appPath = 'http://<MySite>/PWA_RD/'


$packList= @(
'~\Documents\GitHub\Webpart1',
'~\Documents\GitHub\WebPart2',
'~\Documents\GitHub\WebPart',
'~\Src\TestWebpart'
)


function Build-WebPart(){

if ( test-path ./sharepoint\solution) {rm ./sharepoint\solution -force -recurse}
gulp clean
gulp build
gulp bundle  --ship
gulp package-solution  --ship
}




function Export-WebPart(){
if ( test-path ./deploy) { rm ./deploy -force -recurse}


mkdir deploy


#move everything to the release folder
Copy-Item -Recurse .\temp\deploy ./deploy
Copy-Item  .\sharepoint\solution\*.sppkg ./deploy

#remove temp packages 
rm .\temp\deploy -force  -recurse
rm .\sharepoint\solution\*.sppkg -force -recurse


Get-PartEnv test  >  ./deploy/.js_path

}


function Compress-Release($packName){

Compress-Archive -Path .\deploy\ -DestinationPath ./$packName.zip -CompressionLevel Optimal

}


function Copy-Release($packName){

#explorer .\deploy\
cp .\deploy\deploy  $destDir\$packName.deploy -force  -recurse
cp .\deploy\*.sppkg $destDir\$packName.deploy

cp .\deploy\*.zip $destDir
mv .\$packName.zip .\deploy\


cp .\deploy\*.sppkg $destDir

cp ./deploy/.js_path $destDir\$packName.deploy\${packName}.js_deploy 
}


function CheckEnv($partEnv){
 Get-PartEnv $partEnv|%{ if( $_.trim().startswith("//") ){throw "Check the environment for  the $pwd. Currentrly set '$partEnv'!"}}

}

function Get-PartEnv($partEnv){
cat .\config\write-manifests.json | where {$_ -match $partEnv} | %{$_.split('"')[-1,-2] } | select -last 1

}


foreach($part in $packList){
cd "$part"
CheckEnv 'test'
}


echo "start?"
[System.Console]::ReadKey($true)



rm $destDir -recurse -force

foreach($part in $packList){

cd "$part"

$packName = [System.IO.Path]::GetFileName($pwd.path)


echo "--starting $packName deployemnt"

git checkout develop
git pull

Build-WebPart
Export-WebPart
Compress-Release $packName
Copy-Release $packName
echo "-- $packName package ready"
}

cd $destDir
explorer .




function loadLibs(){
Add-Type -Path "$libDir\MICROSOFT.SHAREPOINT.CLIENT.DLL"
Add-Type -Path "$libDir\MICROSOFT.SHAREPOINT.CLIENT.RUNTIME.DLL"
 
}




function Publish-FileApp($file, $url, $DocLibName){

echo "Publishing $file to $url"



$Context=New-Object Microsoft.SharePoint.Client.ClientContext($url)
 
 

#$Context.Credentials=$Creds
#Retrieve list
$List=$Context.Web.Lists.GetByTitle($DocLibName)
$Context.Load($List)
$Context.ExecuteQuery()

#Upload file

	$FileStream=New-Object IO.FileStream($file.FullName,[System.IO.FileMode]::Open)
	$FileCreationInfo=New-Object Microsoft.SharePoint.Client.FileCreationInformation
	$FileCreationInfo.Overwrite=$true
	$FileCreationInfo.ContentStream=$FileStream
	$FileCreationInfo.URL =$file.Name
	$Upload=$List.RootFolder.Files.Add($FileCreationInfo)
	$Context.Load($Upload)
	$Context.ExecuteQuery()

}


function Publish-FolderFile($file, $url, $folder){

echo "Publishing $file to $folder"

$folder = $folder.replace($appPath,'')


$Context=New-Object Microsoft.SharePoint.Client.ClientContext($url)
 
 

#$Context.Credentials=$Creds
#Retrieve list
$Folder=$Context.Web.GetFolderByServerRelativeUrl($folder)
$Context.Load($Folder)
$Context.ExecuteQuery()

#Upload file

	$FileStream=New-Object IO.FileStream($file.FullName,[System.IO.FileMode]::Open)
	$FileCreationInfo=New-Object Microsoft.SharePoint.Client.FileCreationInformation
	$FileCreationInfo.Overwrite=$true
	$FileCreationInfo.ContentStream=$FileStream
	$FileCreationInfo.URL =$file.Name
	$Upload=$Folder.Files.Add($FileCreationInfo)
	$Context.Load($Upload)
	$Context.ExecuteQuery()

}


loadLibs 
cd  $destDir






Foreach ($folder in (ls *.deploy) )
{

Foreach ($file in (ls *.sppkg -File))
{
	 Publish-FileApp  -file $file -url $appCatalogUrl -DocLibName 'Apps for SharePoint'
}

 cd $folder 
 $deployPath = cat *js_deploy
 
 Foreach ($jsFile in ( ls *.js,*.json) ){
	Publish-FolderFile  -file $jsFile -url $appPath -folder $deployPath
 }
}

