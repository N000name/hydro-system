import java.util.Scanner;
public class WaterLevel{
 public static void main(String[]args){
   Scanner sc=new Scanner(System.in);
   double max=0,min=999,sum=0;
   int count=0;
    System.out.println("Input water level,enter -1 to stop");
  while(true){
     double num=sc.nextDouble();
    if(num==-1)break;
     sum+=num;
    if(num>max)max=num;
    if(num<min)min=num;
    count++;
}
     double avg=sum/count;
     System.out.printf("Average: %.2f m\n ",avg);
     System.out.printf("Max: %.2f m\n ",max);

     System.out.printf("Min: %.2f m\n ",min);
      if(max>25.0){
  System.out.println("Warning:Water level over 25m");
} else{
System.out.println ("Water level normal");
}
sc.close();
}}


