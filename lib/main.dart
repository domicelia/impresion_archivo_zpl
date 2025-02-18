import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
//import 'package:esc_pos_utils/esc_pos_utils.dart';
//import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ImpresionArchivosZpl(),
    );
  }
}

class ImpresionArchivosZpl extends StatefulWidget {

  @override
  _ImpresionArchivosZplState createState() => _ImpresionArchivosZplState();
}
class _ImpresionArchivosZplState extends State<ImpresionArchivosZpl> {
  //String filePath= '/storage/emulated/0/Android/data/com.example.impresion_zpl/files/downloads/Etiqueta_producto.txt';
  String filePath= '/storage/emulated/0/Android/data/com.example.impresion_zpl/files/downloads/factura_pos_57.zpl';
  BluetoothDevice? zebraPrinter;
  BluetoothCharacteristic? writeCharacteristic;
  // String zplCode = '''
  // ^XA
  // ^FO50,60^A0,40^FDWorld's Best Griddle^FS
  // ^FO60,120^BY3^BCN,60,,,,A^FD1234ABC^FS
  // ^FO25,25^GB380,200,2^FS
  // ^XZ
  // ''';

  void imprimirArchivo() async {
     Directory? directorioBase = await getDownloadsDirectory();
     directorioBase ??= await getApplicationDocumentsDirectory();
     String directoryPath = p.join(directorioBase.path,'factura_zebra_1.pdf',);
     File file = File(filePath);
      if (file.existsSync()) { //verificar existencia de archivo
        buscarImpresora();
      } else {
        _showDialog("Archivo No Encontrado", "No se encontró el archivo $filePath");
      }
  }
  void buscarImpresora() async {
    var status = await Permission.location.request();
    if (status.isGranted){
      debugPrint("-----iniciando-escaneo---------");
      // conexion directa a primer dispositivo vinculado
      List<BluetoothDevice> bondedDevices = await FlutterBluePlus.bondedDevices; // solo dispositivo vinculado
      debugPrint("Resultados dispositivos vinculado: ${bondedDevices.map((r) => r.remoteId).toList()}");
      if (bondedDevices.isNotEmpty) {
        zebraPrinter = bondedDevices.first;
      }
      // FlutterBluePlus.startScan(timeout: Duration(seconds: 50));
      // FlutterBluePlus.scanResults.listen((List<ScanResult> results) {
      //   var dispositivosConNombre = results.where((r) => r.device.platformName.isNotEmpty).toList();
      //   debugPrint("Resultados del escaneo: ${results.map((r) => r.device.platformName).toList()}");
      //   if (dispositivosConNombre.isNotEmpty) {
      //     zebraPrinter = dispositivosConNombre.first.device;
      //     FlutterBluePlus.stopScan();  // Detiene el escaneo inmediatamente
      //   }
      // });
      
      if (zebraPrinter!=null){
        await zebraPrinter!.connect();
        _showDialog("Conectado", "Conectado a la impresora ${zebraPrinter!.platformName}");
        enviarAImpresora();
        //await zebraPrinter!.disconnect();
      }else{
         _showDialog("No se encontraron impresoras", "No se encontraron impresoras Zebra.");
      }
    } else {
    _showDialog("Permiso Denegado", "Se necesitan permisos de ubicación para escanear dispositivos Bluetooth.");
    }
  }
   void enviarAImpresora() async {
    try{
      List<BluetoothService> services = await zebraPrinter!.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            debugPrint("Característica de escritura encontrada: ${characteristic.uuid}");
            debugPrint("UUID: ${characteristic.uuid} - Propiedades: ${characteristic.properties}");
            writeCharacteristic = characteristic;
            await enviarArchivo(characteristic);
            break;
          }
        }
      }
    }catch (e) {
      _showDialog("ERROR","Error al enviar el archivo: $e");
    }
    
  }
  Future<void> enviarArchivo(BluetoothCharacteristic characteristic) async {
  try {
    File file = File(filePath);
    String zplCode = await file.readAsString();
    List<int> zplBytes = utf8.encode(zplCode);
    int fragmentSize = 128;
    int totalBytes = zplBytes.length;
    for (int i = 0; i < totalBytes; i += fragmentSize) {
      List<int> fragment = zplBytes.sublist(i, (i + fragmentSize) < totalBytes ? (i + fragmentSize) : totalBytes);
      await writeCharacteristic!.write(fragment, withoutResponse: false);
      await Future.delayed(Duration(milliseconds: 50));
     }
    // await writeCharacteristic!.write(zplBytes, withoutResponse: false);
  } catch (e) {
    debugPrint("eerrror: $e");
    _showDialog("ERROR","❌ Error al enviar el archivo: $e");
  }
}
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK"),
            ),
          ],
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("imprimir de archivos")),
      body: Center(
        child: ElevatedButton(
          onPressed: imprimirArchivo,//findFile,
          child: Text("Imprimir en Zebra"),
        ),
      ),
    );
  }
}