import {Component, NgModule} from '@angular/core';
import {RouterModule} from '@angular/router';

@Component({
  selector: 'home',
  templateUrl: './home.html',
})
export class HomeComponent {}

@NgModule({
  declarations: [HomeComponent],
  imports: [
    RouterModule.forChild([{path: '', component: HomeComponent}]),
  ],
})
export class HomeModule {}
