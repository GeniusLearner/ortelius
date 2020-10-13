cd /d F:\CVS\openmake7\src\native\OpenmakeAddin\OpenmakeAddin2005\bin
verpatch /va OpenmakeAddin.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va Interop.SHDocVw.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va Interop.VsWebApplicationHost.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va Interop.VxWebsiteExtensibility.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va Interop.VsWebProjectCBMLib.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va omapi_s.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "OpenmakeAddin.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "Interop.SHDocVw.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "Interop.VsWebApplicationHost.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "Interop.VxWebsiteExtensibility.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "Interop.VsWebProjectCBMLib.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "omapi_s.dll"
cd en 
verpatch /va OpenmakeAddin.resources.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a en\OpenmakeAddin.resources.dll

cd /d F:\CVS\openmake7\src\native\OpenmakeAddin\OpenmakeAddin2008\bin
verpatch /va OpenmakeAddin.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va Interop.SHDocVw.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va Interop.VsWebApplicationHost.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va Interop.VxWebsiteExtensibility.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va Interop.VsWebProjectCBMLib.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va omapi_s.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "OpenmakeAddin.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "Interop.SHDocVw.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "Interop.VsWebApplicationHost.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "Interop.VxWebsiteExtensibility.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "Interop.VsWebProjectCBMLib.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "omapi_s.dll"
cd en 
verpatch /va OpenmakeAddin.resources.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a en\OpenmakeAddin.resources.dll

cd /d F:\CVS\openmake7\src\native\OpenmakeAddin\OpenmakeAddin2010\bin
verpatch /va OpenmakeAddin.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va Interop.SHDocVw.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va Interop.VsWebApplicationHost.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va Interop.VxWebsiteExtensibility.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va Interop.VsWebProjectCBMLib.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
verpatch /va omapi_s.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "OpenmakeAddin.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "Interop.SHDocVw.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "Interop.VsWebApplicationHost.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "Interop.VxWebsiteExtensibility.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "Interop.VsWebProjectCBMLib.dll"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a "omapi_s.dll"
cd en 
verpatch /va OpenmakeAddin.resources.dll "7.4.0.0" /s CompanyName "OpenMake Software" /s "FileDescription" "Meister" /s InternalName "Meister" /s LegalCopyright "Copyright (C) 2011" /s OriginalFilename "Meister" /s ProductName "Meister" /s ProductVersion "7.4.0.0"
signtool sign /t http://timestamp.verisign.com/scripts/timstamp.dll /a en\OpenmakeAddin.resources.dll
