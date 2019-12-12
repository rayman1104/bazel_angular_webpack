import { Component } from '@angular/core';
import * as $protobuf from 'protobufjs/minimal';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent {
  title = 'protobufjs-repro';
}

console.log($protobuf.util.isString('qweqwe'));
