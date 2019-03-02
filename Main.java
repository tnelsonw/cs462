import org.apache.http.HttpResponse;
import org.apache.http.client.HttpClient;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.entity.ContentType;
import org.apache.http.entity.StringEntity;
import org.apache.http.impl.client.HttpClientBuilder;
import org.apache.http.util.EntityUtils;
import org.json.JSONObject;

import java.io.IOException;

public class Main {

  public static void main(String[] args) throws IOException {

    String base_eci = "351UYA3Mrod799KHosaNmM";
    String base_url = "http://localhost:8080/";
    HttpClient client = HttpClientBuilder.create().build();


    String name1 = "60";
    String name2 = "61";
    String new_sensor_url = base_url + "sky/event/" + base_eci + "/lab6testing/sensor/new_sensor?name=";
    String unneeded_sensor_url = base_url + "sky/event/" + base_eci + "/lab6testing/sensor/unneeded_sensor?name=";

    HttpPost post = new HttpPost(new_sensor_url + name1);
    HttpResponse result = client.execute(post);
    String jsonResult = EntityUtils.toString(result.getEntity());

    if(jsonResult.contains("Pico_Created")) {
      System.out.println("New pico creation rule passed testing.");
    }
    else {
      System.out.println("New pico creation failure.");
    }

    HttpPost post2 = new HttpPost(new_sensor_url + name2);
    HttpResponse result2 = client.execute(post2);
    String jsonResult2 = EntityUtils.toString(result2.getEntity());
    JSONObject jsonObject = new JSONObject(jsonResult2);

    if(jsonResult2.contains("Pico_Created")) {
      System.out.println("New pico creation rule passed testing.");
    }
    else {
      System.out.println("New pico creation failure.");
    }

    String child_eci = jsonObject.getJSONArray("directives").getJSONObject(0).getJSONObject("options").getJSONObject("pico").getString("eci");
    String heartbeat_url = base_url + "sky/event/" + child_eci + "/lab6testing/wovyn/heartbeat";
    String profile_url = base_url + "sky/event/" + child_eci + "/lab6testing/wovyn/profile";

    HttpPost heartbeatPost = new HttpPost(heartbeat_url);
    String payLoad = "{\n" +
        "    \"emitterGUID\":\"5CCF7F2BD537\",\n" +
        "    \"eventDomain\":\"wovyn.emitter\",\n" +
        "    \"eventName\":\"sensorHeartbeat\",\n" +
        "    \"genericThing\":{\n" +
        "        \"typeId\":\"2.1.2\",\n" +
        "        \"typeName\":\"generic.simple.temperature\",\n" +
        "        \"healthPercent\":56.89,\n" +
        "        \"heartbeatSeconds\":10,\n" +
        "        \"data\":{\n" +
        "            \"temperature\":[\n" +
        "                {\n" +
        "                    \"name\":\"ambient temperature\",\n" +
        "                    \"transducerGUID\":\"28E3A5680900008D\",\n" +
        "                    \"units\":\"degrees\",\n" +
        "                    \"temperatureF\":15.0,\n" +
        "                    \"temperatureC\":24.06\n" +
        "                }\n" +
        "            ]\n" +
        "        }\n" +
        "    },\n" +
        "    \"property\":{\n" +
        "        \"name\":\"Wovyn_2BD537\",\n" +
        "        \"description\":\"Temp1000\",\n" +
        "        \"location\":{\n" +
        "            \"description\":\"Timbuktu\",\n" +
        "            \"imageURL\":\"http://www.wovyn.com/assets/img/wovyn-logo-small.png\",\n" +
        "            \"latitude\":\"16.77078\",\n" +
        "            \"longitude\":\"-3.00819\"\n" +
        "        }\n" +
        "    },\n" +
        "    \"specificThing\":{\n" +
        "        \"make\":\"Wovyn ESProto\",\n" +
        "        \"model\":\"Temp1000\",\n" +
        "        \"typeId\":\"1.1.2.2.1000\",\n" +
        "        \"typeName\":\"enterprise.wovyn.esproto.wtemp.1000\",\n" +
        "        \"thingGUID\":\"5CCF7F2BD537.1\",\n" +
        "        \"firmwareVersion\":\"Wovyn-WTEMP1000-1.14\",\n" +
        "        \"transducer\":[\n" +
        "            {\n" +
        "                \"name\":\"Maxim DS18B20 Digital Thermometer\",\n" +
        "                \"transducerGUID\":\"28E3A5680900008D\",\n" +
        "                \"transducerType\":\"Maxim Integrated.DS18B20\",\n" +
        "                \"units\":\"degrees\",\n" +
        "                \"temperatureC\":24.06\n" +
        "            }\n" +
        "        ],\n" +
        "        \"battery\":{\n" +
        "            \"maximumVoltage\":3.6,\n" +
        "            \"minimumVoltage\":2.7,\n" +
        "            \"currentVoltage\":3.21\n" +
        "        }\n" +
        "    },\n" +
        "    \"version\":2\n" +
        "}";
    StringEntity entity = new StringEntity(payLoad, ContentType.APPLICATION_JSON);
    heartbeatPost.setEntity(entity);
    HttpResponse heart_response = client.execute(heartbeatPost);
    String heart_json = EntityUtils.toString(heart_response.getEntity());

    if(heart_json.contains("heartbeat detected")) {
      System.out.println("Child pico response correctly to new temperature events.");
    }
    else {
      System.out.println("Child pico temperature response failure.");
    }

    HttpGet profile_get = new HttpGet(profile_url);
    HttpResponse profile_response = client.execute(profile_get);
    String profileJson = EntityUtils.toString(profile_response.getEntity());
    //System.out.println(profileJson);

    String defaultSms = "3154848975";
    String defaultThreshold = "90";
    String defaultLoc = "unknown";
    //using name2
    JSONObject heartbeatObject = new JSONObject(profileJson);
    String actualObject = heartbeatObject.getJSONArray("directives").getJSONObject(0).getString("name");

    if (actualObject.contains(defaultSms) && actualObject.contains(defaultThreshold) && actualObject.contains(defaultLoc) && actualObject.contains(name2)) {
      System.out.println("Profile updated event passed testing");
    }
    else {
      System.out.println("Profile updated event failure");
    }

    HttpPost delPost = new HttpPost(unneeded_sensor_url + name1);
    HttpResponse delResult = client.execute(delPost);
    String delJson = EntityUtils.toString(delResult.getEntity());

    if(delJson.contains("name\":\"" + name1) && delJson.contains("deleting pico")) {
      System.out.println("Pico deletion rule passed testing");
    }
    else {
      System.out.println("Pico deletion failure");
    }




  }

}
